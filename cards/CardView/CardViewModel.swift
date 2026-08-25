//
//  CardViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 28/01/24.
//

import SwiftUI

#if os(iOS)
import PhotosUI
#endif

@MainActor
final class CardViewModel: ObservableObject {

	@Published var card : CardData
	@Published var isEditing = false
	@Published var cardImage: PlatformImage?
	@Published var isShowingScanner = false
	@Published var errorMessage: String?
	@Published var showErrorAlert = false
	@Published private(set) var isImageMutationInProgress = false
	private var imageLoadTask: Task<Void, Never>?
	private var imageMutationTask: Task<Void, Never>?
	private let imageStore: CardImageStore
	private(set) var didUseScanner = false

	#if os(iOS)
	@Published var selectedItem: PhotosPickerItem?
	#endif

	typealias CardUpdateAction = @MainActor (CardData) async -> Bool

	var isAddNewFlow : Bool
	var addUpdateCard: CardUpdateAction

	init(
		card: CardData,
		isEditing: Bool = false,
		addNewFlow: Bool = false,
		addUpdateCard: @escaping CardUpdateAction,
		imageStore: CardImageStore = ICloudDataManager.shared
	) {
		self.card = card
		self.isEditing = isEditing
		self.addUpdateCard = addUpdateCard
		self.isAddNewFlow = addNewFlow
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
		imageLoadTask?.cancel()
		imageMutationTask?.cancel()
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

	func copyAction(with value: String) {
		guard !value.isEmpty else {
			HapticService.trigger(.error)
			return
		}
		PasteboardService.copy(value)
		HapticService.trigger(.success)
	}

	func markScannerCompleted() {
		didUseScanner = true
	}

	/// Dismisses the scanner before writing card fields so SwiftUI does not tear
	/// down a presented cover by removing its presenting toolbar item.
	func applyScannedCard(number: String, name: String, expiration: String) {
		isShowingScanner = false
		card.number = number
		card.name = name
		card.expiration = expiration
		markScannerCompleted()
	}
}
