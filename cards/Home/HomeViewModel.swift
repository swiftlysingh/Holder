//
//  HomeViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 28/01/24.
//

import SwiftUI

class HomeViewModel : ObservableObject {

	@Published var addingType: CardType?
	@Published var selectedCard: CardData?
	@Bindable var cardDataStore = CardDataStore()
	@AppStorage("isFirstLaunch") var isFirstLaunch = true

	var appName: String? {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
	}

	func deleteCard(at offsets: IndexSet, inSection cardType: CardType) {
		offsets.forEach { index in
			guard let card = cardDataStore.cardsByType[cardType]?[index] else { return }
			if cardDataStore.deleteCard(with: card.id) {
				cardDataStore.cardsByType[cardType]?.remove(at: index)
			} else {
				print("Error deleting")
			}
		}
	}

	func archiveCard(_ card: CardData) {
		cardDataStore.archiveCard(card)
	}

	func unarchiveCard(_ card: CardData) {
		cardDataStore.unarchiveCard(card)
	}

	func deleteArchivedCard(_ card: CardData) {
		if cardDataStore.deleteCard(with: card.id) {
			if let index = cardDataStore.archivedCards.firstIndex(where: { $0.id == card.id }) {
				cardDataStore.archivedCards.remove(at: index)
			}
		}
	}

	/// Handles deep link URL from widget (holder://card/{uuid})
	func handleDeepLink(_ url: URL) {
		guard url.scheme == "holder",
			  url.host == "card",
			  let cardIDString = url.pathComponents.last,
			  let cardID = UUID(uuidString: cardIDString) else {
			return
		}

		// Ensure cards are loaded before trying to find the card
		if cardDataStore.cardsByType.values.allSatisfy({ $0.isEmpty }) {
			cardDataStore.loadCards()
		}

		// Use DispatchQueue to ensure view is ready for navigation
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
			if let card = self?.cardDataStore.findCard(by: cardID) {
				self?.selectedCard = card
			}
		}
	}
}
