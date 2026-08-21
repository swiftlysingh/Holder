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

class CardViewModel: ObservableObject {

	@Published var card : CardData
	@Published var isEditing = false
	@Published var cardImage: PlatformImage?
	@Published var isShowingScanner = false
	@Published var errorMessage: String?
	@Published var showErrorAlert = false
	private var imageLoadTask: Task<Void, Never>?
	private let imageStore: CardImageStore
	private(set) var didUseScanner = false

	#if os(iOS)
	@Published var selectedItem: PhotosPickerItem?
	#endif

	var isAddNewFlow : Bool
	var addUpdateCard: (CardData) -> Bool

	init(
		card: CardData,
		isEditing: Bool = false,
		addNewFlow: Bool = false,
		addUpdateCard: @escaping ((CardData) -> Bool),
		imageStore: CardImageStore = ICloudDataManager.shared
	) {
		self.card = card
		self.isEditing = isEditing
		self.addUpdateCard = addUpdateCard
		self.isAddNewFlow = addNewFlow
		self.imageStore = imageStore
		loadStoredImage()
	}

	deinit {
		imageLoadTask?.cancel()
	}

	func loadStoredImage() {
		imageLoadTask?.cancel()
		let store = imageStore
		let id = card.id
		imageLoadTask = Task { [weak self] in
			let image = await store.loadImage(for: id)
			guard !Task.isCancelled else { return }
			await MainActor.run {
				self?.cardImage = image
			}
		}
	}

	func saveStoredImage(_ image: PlatformImage) async -> Bool {
		let saved = await imageStore.saveImage(image, for: card.id)
		guard saved else { return false }
		await MainActor.run {
			cardImage = image
		}
		return true
	}

	func removeStoredImage() {
		cardImage = nil
		let store = imageStore
		let id = card.id
		Task {
			await store.deleteImage(for: id)
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
}
