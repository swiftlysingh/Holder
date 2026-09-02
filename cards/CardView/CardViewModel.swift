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
	@Published var selectedCardType: CardType? {
		didSet {
			if let selectedCardType {
				card.type = selectedCardType
			}
		}
	}
	@Published var errorMessage: String?
	@Published var showErrorAlert = false
	@Published private(set) var isImageMutationInProgress = false
	@Published private(set) var isSaving = false
	private var imageLoadTask: Task<Void, Never>?
	private var imageMutationTask: Task<Void, Never>?
	private let imageStore: CardImageStore
	private(set) var didUseScanner = false
	let startMode: CardEditorStartMode

	#if os(iOS)
	@Published var selectedItem: PhotosPickerItem?
	#endif

	typealias CardUpdateAction = @MainActor (CardData) async -> Bool

	var isAddNewFlow : Bool
	var addUpdateCard: CardUpdateAction
	var canFinishEditing: Bool {
		guard let selectedCardType else { return false }
		return selectedCardType == .other || !card.number.isEmpty
	}

	init(
		card: CardData,
		isEditing: Bool = false,
		addNewFlow: Bool = false,
		startMode: CardEditorStartMode = .scanner,
		addUpdateCard: @escaping CardUpdateAction,
		imageStore: CardImageStore = ICloudDataManager.shared
	) {
		self.card = card
		self.isEditing = isEditing
		self.addUpdateCard = addUpdateCard
		self.isAddNewFlow = addNewFlow
		self.startMode = startMode
		self.imageStore = imageStore
		self.selectedCardType = addNewFlow ? nil : card.type
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

	@discardableResult
	func copyAction(with value: String) -> Bool {
		guard !value.isEmpty else {
			HapticService.trigger(.error)
			return false
		}
		PasteboardService.copy(value)
		HapticService.trigger(.success)
		return true
	}

	func saveCard() async -> Bool? {
		guard isEditing, canFinishEditing, !isSaving else { return nil }

		isSaving = true
		defer { isSaving = false }

		let succeeded = await addUpdateCard(card)
		if succeeded {
			isEditing = false
		}
		return succeeded
	}

	func applyScan(_ result: CardScanResult) {
		CardScanSession.apply(result, to: &card)
		didUseScanner = true
		isShowingScanner = false
		isEditing = true
	}
}

enum CardEditorStartMode: Equatable {
	case scanner
	case manual
}
