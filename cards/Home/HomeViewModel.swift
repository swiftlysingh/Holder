//
//  HomeViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 28/01/24.
//

import SwiftUI

class HomeViewModel: ObservableObject {

	@Published var addingType: CardType?
	@Published var selectedCard: CardData?
	@Bindable var cardDataStore: CardDataStore
	@AppStorage("isFirstLaunch") var isFirstLaunch = true

	init(cardDataStore: CardDataStore = CardDataStore()) {
		self.cardDataStore = cardDataStore
	}

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

		Task { @MainActor in
			// Ensure cards are loaded before trying to find the card
			if cardDataStore.cardsByType.values.allSatisfy({ $0.isEmpty }) {
				cardDataStore.loadCards()
			}

			// Retry finding the card with exponential backoff instead of fixed delay
			await findAndSelectCard(by: cardID)
		}
	}

	/// Attempts to find and select a card with retries
	@MainActor
	private func findAndSelectCard(by cardID: UUID, attempt: Int = 0) async {
		let maxAttempts = 5
		let baseDelay: UInt64 = 50_000_000 // 50ms

		if let card = cardDataStore.findCard(by: cardID) {
			selectedCard = card
			return
		}

		// Retry with exponential backoff if card not found
		if attempt < maxAttempts {
			let delay = baseDelay * UInt64(1 << attempt) // 50ms, 100ms, 200ms, 400ms, 800ms
			try? await Task.sleep(nanoseconds: delay)
			await findAndSelectCard(by: cardID, attempt: attempt + 1)
		}
	}
}
