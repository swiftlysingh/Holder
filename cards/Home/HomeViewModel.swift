//
//  HomeViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 28/01/24.
//

import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {

	@Published var isAddingCard = false
	@Published var selectedCard: CardData?
	@Bindable var cardDataStore: CardDataStore
	var addCardStartMode: CardEditorStartMode = .scanner
	private var deepLinkTask: Task<Void, Never>?
	/// Held until the add-card sheet's dismiss animation finishes. Selecting
	/// immediately tears down the iOS 18 zoom source while UIKit is still
	/// morphing `PresentationHostingController` (HOLDER-IOS-1 / #117).
	private var pendingCardSelection: CardData?

	init(cardDataStore: CardDataStore? = nil) {
		self.cardDataStore = cardDataStore ?? CardDataStore()
	}

	deinit {
		deepLinkTask?.cancel()
	}

	var appName: String? {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
	}

	/// Handles deep link URL from widget (holder://card/{uuid})
	/// - Parameter onOpenedFromWidget: Invoked only after a matching card is selected.
	func handleDeepLink(_ url: URL, onOpenedFromWidget: (() -> Void)? = nil) {
		guard url.scheme == "holder",
			  url.host == "card",
			  let cardIDString = url.pathComponents.last,
			  let cardID = UUID(uuidString: cardIDString) else {
			return
		}

		deepLinkTask?.cancel()
		deepLinkTask = Task { @MainActor [weak self] in
			guard let self else { return }

			// Ensure cards are loaded before trying to find the card
			if cardDataStore.cardsByType.values.allSatisfy({ $0.isEmpty }) {
				await cardDataStore.loadCards()
			}

			// Retry finding the card with exponential backoff instead of fixed delay
			await findAndSelectCard(by: cardID, onOpenedFromWidget: onOpenedFromWidget)
		}
	}

	/// Attempts to find and select a card with retries
	@MainActor
	private func findAndSelectCard(
		by cardID: UUID,
		attempt: Int = 0,
		onOpenedFromWidget: (() -> Void)? = nil
	) async {
		guard !Task.isCancelled else { return }

		let maxAttempts = 5
		let baseDelay: UInt64 = 50_000_000 // 50ms

		if let card = cardDataStore.findCard(by: cardID) {
			selectCard(card)
			onOpenedFromWidget?()
			return
		}

		// Retry with exponential backoff if card not found
		if attempt < maxAttempts {
			let delay = baseDelay * UInt64(1 << attempt) // 50ms, 100ms, 200ms, 400ms, 800ms
			do {
				try await Task.sleep(nanoseconds: delay)
			} catch {
				return
			}
			await findAndSelectCard(
				by: cardID,
				attempt: attempt + 1,
				onOpenedFromWidget: onOpenedFromWidget
			)
		}
	}

	/// Selects a card unless the add-card sheet is up, in which case the
	/// selection waits so the zoom morph source stays in the hierarchy.
	func selectCard(_ card: CardData) {
		if isAddingCard {
			pendingCardSelection = card
			return
		}
		selectedCard = card
	}

	/// Dismisses the add-card sheet and reveals `card` only after that
	/// presentation has finished tearing down.
	func finishAddingCard(selecting card: CardData) {
		pendingCardSelection = card
		isAddingCard = false
	}

	func revealPendingCardSelection() {
		guard let card = pendingCardSelection else { return }
		pendingCardSelection = nil
		selectedCard = card
	}
}
