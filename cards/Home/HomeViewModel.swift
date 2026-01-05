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

	/// Handles deep link URL from widget (holder://card/{uuid})
	func handleDeepLink(_ url: URL) {
		guard url.scheme == "holder",
			  url.host == "card",
			  let cardIDString = url.pathComponents.last,
			  let cardID = UUID(uuidString: cardIDString) else {
			return
		}
		if let card = cardDataStore.findCard(by: cardID) {
			selectedCard = card
		}
	}
}
