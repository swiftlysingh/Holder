//
//  CardViewModel.swift
//  Holder
//

import LocalAuthentication
import SwiftUI

#if !os(macOS)
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

/// The only data that can be temporarily revealed on a card face.
enum CardSensitiveField: String, Identifiable, Sendable {
	case number
	case expiration
	case securityCode
	case holderName

	var id: String { rawValue }

	var accessibilityName: String {
		switch self {
		case .number: "card number"
		case .expiration: "expiration date"
		case .securityCode: "security code"
		case .holderName: "cardholder name"
		}
	}
}

/// Owns card authentication and the deliberately short-lived display state for sensitive values.
class CardViewModel: ObservableObject {
	private enum LegacyImageChange {
		case none
		case replace(PlatformImage)
		case remove
	}

	@Published var card: CardData
	@Published var isEditing = false
	@Published var cardImage: PlatformImage?
	@Published var isAuthenticated = false
	@Published private(set) var isAuthenticating = false
	@Published var errorMessage: String?
	@Published var showErrorAlert = false
	@Published private(set) var revealedField: CardSensitiveField?
	@Published private(set) var copiedField: CardSensitiveField?
	@Published private(set) var isShowingBack = false
	@Published private(set) var hasUnresolvedLegacyImageMutation = false

	private var scheduledLockTask: Task<Void, Never>?
	private var scheduledLockDeadline: ContinuousClock.Instant?
	private var disclosureTask: Task<Void, Never>?
	private var copiedStateTask: Task<Void, Never>?
	private var activeAuthenticator: CardAuthenticating?
	private var authAttemptID: UInt64 = 0
	private var disclosureAttemptID: UInt64 = 0
	private var copiedStateAttemptID: UInt64 = 0
	private let authenticatorFactory: CardAuthenticatorFactory
	private let sleeper: AsyncSleeper
	private let loadLegacyImage: (UUID) -> PlatformImage?
	private let saveLegacyImage: (PlatformImage, UUID) -> Bool
	private let deleteLegacyImage: (UUID) -> Bool
	private var revealDeadline: Date?
	private(set) var didUseScanner = false
	private var legacyImageChange: LegacyImageChange = .none
	private var persistedLegacyImage: PlatformImage?
	private var persistedLegacyImagePresence: Bool?
	private var hasLoadedLegacyImage = false
	private var didApplyLegacyImageChange = false
	private var hasDurableLegacyImageMarker = false
	private var durableLegacyImageMarkerCard: CardData?

	#if !os(macOS)
	@Published var selectedItem: PhotosPickerItem?
	#endif

	var isAddNewFlow: Bool
	var addUpdateCard: (CardData) -> Bool
	/// A picker captures this before loading bytes. Relock or a newer authentication
	/// attempt changes the value, so a stale completion cannot repopulate plaintext.
	var authenticationGeneration: UInt64 { authAttemptID }

	init(
		card: CardData,
		isEditing: Bool = false,
		addNewFlow: Bool = false,
		addUpdateCard: @escaping ((CardData) -> Bool),
		authenticatorFactory: CardAuthenticatorFactory = DefaultCardAuthenticatorFactory(),
		sleeper: AsyncSleeper = TaskAsyncSleeper(),
		loadLegacyImage: @escaping (UUID) -> PlatformImage? = { ICloudDataManager.shared.loadImage(for: $0) },
		saveLegacyImage: @escaping (PlatformImage, UUID) -> Bool = { ICloudDataManager.shared.saveImage($0, for: $1) },
		deleteLegacyImage: @escaping (UUID) -> Bool = { ICloudDataManager.shared.deleteImage(for: $0) }
	) {
		self.card = card
		self.isEditing = isEditing
		self.addUpdateCard = addUpdateCard
		self.isAddNewFlow = addNewFlow
		self.authenticatorFactory = authenticatorFactory
		self.sleeper = sleeper
		self.loadLegacyImage = loadLegacyImage
		self.saveLegacyImage = saveLegacyImage
		self.deleteLegacyImage = deleteLegacyImage
		// A true value on any card type is a conservative cleanup marker. Older
		// payment-card payloads that predate this flag are definitively image-free.
		persistedLegacyImagePresence = card.hasLegacyImage == true
			? true
			: (card.type == .otherCard ? card.hasLegacyImage : false)
		// Legacy Other Card photos are deliberately loaded only after Holder has
		// authenticated the viewer. New edits are staged in memory until Done.
		cardImage = nil
	}

	deinit {
		scheduledLockTask?.cancel()
		disclosureTask?.cancel()
		copiedStateTask?.cancel()
		activeAuthenticator?.invalidate()
		activeAuthenticator = nil
	}

	func authenticateUser() {
		invalidateCurrentAuthAttempt()

		if !UserSettings.shared.isAuthEnabled {
			isAuthenticated = true
			loadLegacyImageIfNeeded()
			return
		}

		let authenticator = authenticatorFactory.makeAuthenticator()
		activeAuthenticator = authenticator
		let attemptID = authAttemptID
		let reason = "Authenticate to access this card in Holder."

		guard authenticator.canEvaluateDeviceOwnerAuthentication() else {
			authenticator.invalidate()
			activeAuthenticator = nil
			isAuthenticating = false
			isAuthenticated = false
			errorMessage = "Device-owner authentication is not available on this device."
			showErrorAlert = true
			return
		}

		isAuthenticating = true
		authenticator.evaluateDeviceOwnerAuthentication(reason: reason) { [weak self] success in
			Task { @MainActor in
				guard let self, attemptID == self.authAttemptID else { return }
				self.activeAuthenticator = nil
				self.isAuthenticating = false

				if !UserSettings.shared.isAuthEnabled {
					self.isAuthenticated = true
					self.loadLegacyImageIfNeeded()
					return
				}

				self.isAuthenticated = success
				if success {
					self.loadLegacyImageIfNeeded()
				}
			}
		}
	}

	/// Shows one sensitive value for a short, finite interval. The main card face
	/// remains masked until the person explicitly chooses this action.
	func reveal(_ field: CardSensitiveField, for duration: Duration = .seconds(12)) {
		guard isAuthenticated else {
			HapticService.trigger(.error)
			return
		}

		disclosureAttemptID &+= 1
		let attemptID = disclosureAttemptID
		disclosureTask?.cancel()
		revealedField = field
		isShowingBack = field == .securityCode
		let components = duration.components
		let interval = Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
		revealDeadline = Date().addingTimeInterval(max(interval, 0))

		disclosureTask = Task { @MainActor [weak self] in
			do {
				try await Task.sleep(for: duration)
			} catch {
				return
			}
			guard let self, !Task.isCancelled, attemptID == self.disclosureAttemptID else { return }
			HapticService.trigger(.light)
			self.clearTemporaryDisclosure()
		}
	}

	func flipCard() {
		guard isAuthenticated else {
			HapticService.trigger(.error)
			return
		}
		if isShowingBack {
			HapticService.trigger(.light)
			clearTemporaryDisclosure()
		} else {
			HapticService.trigger(.light)
			reveal(.securityCode)
		}
	}

	func isRevealed(_ field: CardSensitiveField) -> Bool {
		revealedField == field
	}

	/// The visual countdown is intentionally derived from a wall-clock deadline
	/// instead of a second timer, so it remains truthful after UI scheduling
	/// delays. The scheduled disclosure task remains the authority that re-masks
	/// the value.
	func remainingRevealSeconds(at date: Date = Date()) -> Int? {
		guard let revealDeadline, revealedField != nil else { return nil }
		return max(0, Int(revealDeadline.timeIntervalSince(date).rounded(.up)))
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
		clearTemporaryDisclosure()
		isAuthenticated = false
		// A staged replacement carries plaintext pixels. Once a cleanup marker has
		// been durably persisted, relocking can abandon the in-memory transaction
		// while preserving a discoverable cleanup path across process termination.
		if let durableLegacyImageMarkerCard {
			card = durableLegacyImageMarkerCard
			persistedLegacyImagePresence = true
			legacyImageChange = .none
			didApplyLegacyImageChange = false
			hasDurableLegacyImageMarker = false
			self.durableLegacyImageMarkerCard = nil
			hasUnresolvedLegacyImageMutation = false
		} else {
			switch legacyImageChange {
			case .replace, .remove:
				legacyImageChange = .none
				card.hasLegacyImage = persistedLegacyImagePresence
			case .none:
				break
			}
		}
		cardImage = nil
		persistedLegacyImage = nil
		hasLoadedLegacyImage = false
		#if !os(macOS)
		selectedItem = nil
		#endif
	}

	/// Revealed values are never kept on screen while Holder is backgrounded,
	/// even when the user chose a longer app-level authentication timeout.
	func hideSensitiveValues() {
		clearTemporaryDisclosure()
	}

	func copyAction(with value: String, field: CardSensitiveField? = nil) {
		guard isAuthenticated,
			!value.isEmpty,
			field.map({ self.isRevealed($0) }) ?? true else {
			HapticService.trigger(.error)
			return
		}

		PasteboardService.copy(value)
		HapticService.trigger(.light)
		guard let field else { return }

		copiedStateAttemptID &+= 1
		let attemptID = copiedStateAttemptID
		copiedStateTask?.cancel()
		copiedField = field
		copiedStateTask = Task { @MainActor [weak self] in
			do {
				try await Task.sleep(for: .seconds(2))
			} catch {
				return
			}
			guard let self, !Task.isCancelled, attemptID == self.copiedStateAttemptID else { return }
			self.copiedField = nil
		}
	}


	/// Applies a card-scan result only to the authenticated add-card session that
	/// launched it. Backgrounding, locking, or starting a newer authentication
	/// attempt changes `authenticationGeneration`, so delayed scanner callbacks
	/// cannot repopulate a locked or replaced draft.
	@discardableResult
	func applyScannerResult(
		number: String,
		holder: String?,
		expiration: String?,
		authenticationGeneration: UInt64
	) -> Bool {
		guard isAuthenticated,
			authenticationGeneration == authAttemptID,
			isAddNewFlow,
			isEditing else {
			return false
		}

		card.number = number
		card.name = holder ?? ""
		card.expiration = expiration ?? ""
		didUseScanner = true
		return true
	}

	/// Stages a legacy Other Card photo so cancelling the editor never writes to
	/// iCloud. The compatibility path remains explicit because it is not part of
	/// the encrypted document vault.
	@discardableResult
	func stageLegacyImage(_ image: PlatformImage, authenticationGeneration: UInt64) -> Bool {
		guard isAuthenticated,
			authenticationGeneration == authAttemptID,
			card.type == .otherCard,
			!hasUnresolvedLegacyImageMutation else {
			return false
		}
		legacyImageChange = .replace(image)
		cardImage = image
		card.hasLegacyImage = true
		return true
	}

	func stageLegacyImageRemoval() {
		guard isAuthenticated, !hasUnresolvedLegacyImageMutation else { return }
		switch legacyImageChange {
		case .replace:
			// Removing an unsaved replacement restores the previously known state;
			// it must not delete an older iCloud image implicitly.
			legacyImageChange = .none
			card.hasLegacyImage = persistedLegacyImagePresence
			cardImage = persistedLegacyImage
			return
		case .none:
			legacyImageChange = persistedLegacyImagePresence == false ? .none : .remove
		case .remove:
			break
		}
		cardImage = nil
		card.hasLegacyImage = false
	}

	/// Changing a legacy Other Card into another type must not leave its
	/// plaintext iCloud compatibility photo orphaned.
	func stageLegacyImageRemovalIfNoLongerNeeded() {
		guard card.type != .otherCard,
			isAuthenticated else { return }
		if didApplyLegacyImageChange, case .replace = legacyImageChange {
			// Keep the applied operation distinguishable until apply can remove the
			// replacement that is already live in iCloud.
			cardImage = nil
			card.hasLegacyImage = false
			return
		}
		switch legacyImageChange {
		case .replace, .none:
			// A replacement may have hidden an older compatibility image. Changing
			// away from Other Card must still remove that older remote image.
			legacyImageChange = persistedLegacyImagePresence == false ? .none : .remove
		case .remove:
			break
		}
		cardImage = nil
		card.hasLegacyImage = false
	}

	/// Persists a conservative cleanup marker before any legacy iCloud mutation.
	/// If Holder terminates at any later point, deleting or editing the visible
	/// card will still retry removal rather than leaving an undiscoverable file.
	func persistLegacyImageMutationMarkerForSave() -> Bool {
		guard case .none = legacyImageChange else {
			if hasDurableLegacyImageMarker { return true }

			var marker = card
			marker.hasLegacyImage = true
			guard addUpdateCard(marker) else { return false }

			hasDurableLegacyImageMarker = true
			durableLegacyImageMarkerCard = marker
			hasUnresolvedLegacyImageMutation = true
			return true
		}
		return true
	}

	/// Applies a staged iCloud mutation only after its cleanup marker is durable.
	func applyLegacyImageChangesForSave() -> Bool {
		guard case .none = legacyImageChange else {
			guard hasDurableLegacyImageMarker else { return false }
			return applyMarkedLegacyImageChange()
		}
		return true
	}

	private func applyMarkedLegacyImageChange() -> Bool {
		if didApplyLegacyImageChange {
			switch legacyImageChange {
			case .replace:
				if card.type == .otherCard {
					card.hasLegacyImage = true
					return true
				}
				// A replacement is already live after a final metadata write failed.
				// Remove it if the retry changes type while the marker remains durable.
				guard deleteLegacyImage(card.id) else { return false }
				legacyImageChange = .remove
				cardImage = nil
				card.hasLegacyImage = false
				persistedLegacyImage = nil
				hasUnresolvedLegacyImageMutation = true
				return true
			case .remove:
				card.hasLegacyImage = false
				return true
			case .none:
				return true
			}
		}
		switch legacyImageChange {
		case .none:
			return true
		case .replace(let image):
			guard saveLegacyImage(image, card.id) else {
				return false
			}
			didApplyLegacyImageChange = true
			hasUnresolvedLegacyImageMutation = true
			return true
		case .remove:
			guard deleteLegacyImage(card.id) else {
				return false
			}
			didApplyLegacyImageChange = true
			hasUnresolvedLegacyImageMutation = true
			return true
		}
	}

	func finalizeLegacyImageChangesAfterSave() {
		guard didApplyLegacyImageChange || hasDurableLegacyImageMarker else { return }
		switch legacyImageChange {
		case .replace(let image):
			persistedLegacyImage = image
			cardImage = image
		case .remove:
			persistedLegacyImage = nil
			cardImage = nil
		case .none:
			break
		}
		persistedLegacyImagePresence = card.hasLegacyImage
		legacyImageChange = .none
		didApplyLegacyImageChange = false
		hasDurableLegacyImageMarker = false
		durableLegacyImageMarkerCard = nil
		hasUnresolvedLegacyImageMutation = false
	}

	func discardLegacyImageChanges() {
		guard !hasUnresolvedLegacyImageMutation else { return }
		legacyImageChange = .none
		didApplyLegacyImageChange = false
		hasDurableLegacyImageMarker = false
		durableLegacyImageMarkerCard = nil
		card.hasLegacyImage = persistedLegacyImagePresence
		cardImage = nil
		persistedLegacyImage = nil
		hasLoadedLegacyImage = false
		if isAuthenticated {
			loadLegacyImageIfNeeded()
		}
	}

	private func loadLegacyImageIfNeeded() {
		guard card.type == .otherCard else {
			cardImage = nil
			return
		}

		switch legacyImageChange {
		case .replace(let image):
			cardImage = image
			return
		case .remove:
			cardImage = nil
			return
		case .none:
			break
		}

		guard !hasLoadedLegacyImage else { return }
		let image = loadLegacyImage(card.id)
		persistedLegacyImage = image
		cardImage = image
		if image != nil {
			card.hasLegacyImage = true
			persistedLegacyImagePresence = true
		}
		hasLoadedLegacyImage = true
	}

	private func clearTemporaryDisclosure() {
		disclosureAttemptID &+= 1
		disclosureTask?.cancel()
		disclosureTask = nil
		revealedField = nil
		isShowingBack = false
		revealDeadline = nil
		copiedStateAttemptID &+= 1
		copiedStateTask?.cancel()
		copiedStateTask = nil
		copiedField = nil
	}

	private func invalidateCurrentAuthAttempt() {
		authAttemptID &+= 1
		activeAuthenticator?.invalidate()
		activeAuthenticator = nil
		isAuthenticating = false
	}
}
