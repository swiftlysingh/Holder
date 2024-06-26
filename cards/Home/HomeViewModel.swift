//
//  HomeViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 28/01/24.
//

import SwiftUI

class HomeViewModel : ObservableObject {

	@Published var showingPopover = false
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
}
