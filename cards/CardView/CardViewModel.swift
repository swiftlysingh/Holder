//
//  CardViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 28/01/24.
//

import SwiftUI
import LocalAuthentication

#if os(iOS)
import PhotosUI
#endif

/// Abstraction over LocalAuthentication so tests can drive completions without a real prompt.
protocol CardAuthenticating: AnyObject {
	func canEvaluateDeviceOwnerAuthentication() -> Bool
	func evaluateDeviceOwnerAuthentication(reason: String, reply: @escaping (Bool) -> Void)
	func invalidate()
}

protocol CardAuthenticatorFactory {
	func makeAuthenticator() -> CardAuthenticating
}

protocol AsyncSleeper {
	func sleep(for duration: Duration) async throws
}

struct TaskAsyncSleeper: AsyncSleeper {
	func sleep(for duration: Duration) async throws {
		try await Task.sleep(for: duration)
	}
}

final class LACardAuthenticator: CardAuthenticating {
	private let context = LAContext()

	func canEvaluateDeviceOwnerAuthentication() -> Bool {
		var error: NSError?
		return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
	}

	func evaluateDeviceOwnerAuthentication(reason: String, reply: @escaping (Bool) -> Void) {
		context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
			reply(success)
		}
	}

	func invalidate() {
		context.invalidate()
	}
}

struct DefaultCardAuthenticatorFactory: CardAuthenticatorFactory {
	func makeAuthenticator() -> CardAuthenticating {
		LACardAuthenticator()
	}
}

@MainActor
final class CardViewModel: ObservableObject {

	@Published var card : CardData
	@Published var isEditing = false
	@Published var cardImage: PlatformImage?
	@Published var isAuthenticated = false
	@Published var isShowingScanner = false
	@Published var errorMessage: String?
	@Published var showErrorAlert = false
	@Published private(set) var isImageMutationInProgress = false
	private var scheduledLockTask: Task<Void, Never>?
	private var imageLoadTask: Task<Void, Never>?
	private var imageMutationTask: Task<Void, Never>?
	private var scheduledLockDeadline: ContinuousClock.Instant?
	private var activeAuthenticator: CardAuthenticating?
	private var authAttemptID: UInt64 = 0
	private let authenticatorFactory: CardAuthenticatorFactory
	private let sleeper: AsyncSleeper
	private let imageStore: CardImageStore
	private(set) var didUseScanner = false

	#if os(iOS)
	@Published var selectedItem: PhotosPickerItem?
	#endif

	typealias CardUpdateAction = @MainActor (CardData) async -> Bool

	var isAddNewFlow : Bool
	var addUpdateCard: CardUpdateAction

	/// True while a device-owner evaluation is in flight for the current attempt.
	var isAuthenticating: Bool { activeAuthenticator != nil }

	init(
		card: CardData,
		isEditing: Bool = false,
		addNewFlow: Bool = false,
		addUpdateCard: @escaping CardUpdateAction,
		authenticatorFactory: CardAuthenticatorFactory = DefaultCardAuthenticatorFactory(),
		sleeper: AsyncSleeper = TaskAsyncSleeper(),
		imageStore: CardImageStore = ICloudDataManager.shared
	) {
		self.card = card
		self.isEditing = isEditing
		self.addUpdateCard = addUpdateCard
		self.isAddNewFlow = addNewFlow
		self.authenticatorFactory = authenticatorFactory
		self.sleeper = sleeper
		self.imageStore = imageStore
		let id = card.id
		imageLoadTask = Task { [weak self, imageStore, id] in
			let data = await imageStore.loadImageData(for: id)
			let image: PlatformImage?
			if let data {
				image = await CardImageData.decodeOffMain(data)
			} else {
				image = nil
			}
			guard !Task.isCancelled else { return }
			self?.cardImage = image
		}
	}

	deinit {
		scheduledLockTask?.cancel()
		imageLoadTask?.cancel()
		imageMutationTask?.cancel()
		activeAuthenticator?.invalidate()
		activeAuthenticator = nil
	}

	func saveStoredImage(
		loadData: @escaping @Sendable () async throws -> Data
	) {
		let store = imageStore
		let id = card.id
		performImageMutation {
			let data = try await loadData()
			guard let image = await CardImageData.decodeOffMain(data) else {
				throw URLError(.cannotDecodeContentData)
			}
			guard await store.saveImageData(data, for: id) else {
				throw URLError(.cannotCreateFile)
			}
			return image
		}
	}

	func removeStoredImage() {
		let store = imageStore
		let id = card.id
		performImageMutation {
			guard await store.deleteImage(for: id) else {
				throw URLError(.cannotRemoveFile)
			}
			return nil
		}
	}

	private func performImageMutation(
		_ operation: @escaping @MainActor @Sendable () async throws -> PlatformImage?
	) {
		guard !isImageMutationInProgress else { return }
		imageLoadTask?.cancel()
		isImageMutationInProgress = true
		imageMutationTask = Task { @MainActor [weak self] in
			defer { self?.isImageMutationInProgress = false }
			do {
				let image = try await operation()
				guard !Task.isCancelled else { return }
				self?.cardImage = image
				self?.errorMessage = nil
			} catch is CancellationError {
				return
			} catch {
				self?.errorMessage = "Unable to update image: \(error.localizedDescription)"
				self?.showErrorAlert = true
			}
		}
	}

	func authenticateUser() {
		invalidateCurrentAuthAttempt()

		if !UserSettings.shared.isAuthEnabled {
			isAuthenticated = true
			return
		}

		let authenticator = authenticatorFactory.makeAuthenticator()
		activeAuthenticator = authenticator
		let attemptID = authAttemptID
		let reason = "Please authenticate to view your card details."

		guard authenticator.canEvaluateDeviceOwnerAuthentication() else {
			authenticator.invalidate()
			activeAuthenticator = nil
			isAuthenticated = false
			return
		}

		authenticator.evaluateDeviceOwnerAuthentication(reason: reason) { [weak self] success in
			Task { @MainActor in
				guard let self else { return }
				guard attemptID == self.authAttemptID else { return }
				self.activeAuthenticator = nil

				if !UserSettings.shared.isAuthEnabled {
					self.isAuthenticated = true
					return
				}

				self.isAuthenticated = success
			}
		}
	}

	func scheduleLock(after duration: Duration) {
		cancelScheduledLock()
		let clock = ContinuousClock()
		let sleeper = self.sleeper
		scheduledLockDeadline = clock.now.advanced(by: duration)
		scheduledLockTask = Task { @MainActor [weak self, sleeper] in
			do {
				try await sleeper.sleep(for: duration)
			} catch {
				// Includes cancellation and injected sleeper failures; leave auth state alone.
				return
			}
			guard !Task.isCancelled, let self else { return }
			self.lock()
		}
	}

	/// Resolves a pending lock when the scene becomes active. The explicit deadline
	/// check prevents app suspension from cancelling an already-expired lock task.
	func resolveScheduledLockOnActive(at now: ContinuousClock.Instant? = nil) {
		guard let deadline = scheduledLockDeadline else { return }
		let currentInstant = now ?? ContinuousClock().now
		if currentInstant >= deadline {
			lock()
		} else {
			cancelScheduledLock()
		}
	}

	func cancelScheduledLock() {
		scheduledLockTask?.cancel()
		scheduledLockTask = nil
		scheduledLockDeadline = nil
	}

	func lock() {
		cancelScheduledLock()
		invalidateCurrentAuthAttempt()
		isAuthenticated = false
	}

	func copyAction(with value: String) {
		guard !value.isEmpty else {
			HapticService.trigger(.error)
			return
		}
		PasteboardService.copy(value)
		HapticService.trigger(.success)
	}

	private func invalidateCurrentAuthAttempt() {
		authAttemptID &+= 1
		activeAuthenticator?.invalidate()
		activeAuthenticator = nil
	}

	func markScannerCompleted() {
		didUseScanner = true
	}
}
