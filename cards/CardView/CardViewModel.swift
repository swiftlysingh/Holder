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
		addUpdateCard: @escaping ((CardData) -> Bool)
	) {
		self.card = card
		self.isEditing = isEditing
		self.addUpdateCard = addUpdateCard
		self.isAddNewFlow = addNewFlow
		cardImage = ICloudDataManager.shared.loadImage(for: card.id)
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
