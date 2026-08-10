//
//  HomeViewModel.swift
//  Holder
//

import SwiftUI

enum VaultFilter: String, CaseIterable, Identifiable {
	case all = "All"
	case cards = "Cards"
	case documents = "Documents"

	var id: Self { self }
}

enum VaultDestination: Hashable, Identifiable {
	case card(UUID)
	case document(UUID)

	var id: String {
		switch self {
		case .card(let id): "card-\(id.uuidString)"
		case .document(let id): "document-\(id.uuidString)"
		}
	}
}

enum VaultAddKind: Identifiable {
	case card
	case document

	var id: String {
		switch self {
		case .card: "card"
		case .document: "document"
		}
	}
}

enum VaultDeckItem: Identifiable, Hashable {
	case card(CardData)
	case document(DocumentData)

	var id: String {
		switch self {
		case .card(let card): "card-\(card.id.uuidString)"
		case .document(let document): "document-\(document.id.uuidString)"
		}
	}

	var title: String {
		switch self {
		case .card(let card):
			return card.displayLabel
		case .document(let document):
			return document.title
		}
	}

	var destination: VaultDestination {
		switch self {
		case .card(let card): .card(card.id)
		case .document(let document): .document(document.id)
		}
	}

	var isFavorite: Bool {
		switch self {
		case .card(let card): card.isFavorite
		case .document(let document): document.isFavorite
		}
	}

	var sortIndex: Int? {
		switch self {
		case .card(let card): card.sortIndex
		case .document(let document): document.sortIndex
		}
	}
}

@MainActor
final class HomeViewModel: ObservableObject {
	@Published var selectedItem: VaultDestination?
	@Published var addingKind: VaultAddKind?
	@Published var filter: VaultFilter = .all
	@Published var searchText = ""
	@Published var isSearching = false
	@Published private(set) var isLoading = false
	@Published private(set) var loadingError: String?
	@AppStorage("isFirstLaunch") var isFirstLaunch = true

	@Bindable var cardDataStore: CardDataStore
	@Bindable var documentDataStore: DocumentDataStore
	private var deepLinkTask: Task<Void, Never>?

	init(
		cardDataStore: CardDataStore = CardDataStore(),
		documentDataStore: DocumentDataStore = DocumentDataStore()
	) {
		self.cardDataStore = cardDataStore
		self.documentDataStore = documentDataStore
	}

	deinit {
		deepLinkTask?.cancel()
	}

	var activeCards: [CardData] {
		CardType.allCases.flatMap { cardDataStore.cardsByType[$0] ?? [] }
	}

	var visibleItems: [VaultDeckItem] {
		let query = normalizedSearchText
		var items: [VaultDeckItem] = []
		if filter != .documents {
			items += activeCards
				.filter { matches($0, query: query) }
				.map(VaultDeckItem.card)
		}
		if filter != .cards {
			items += documentDataStore.documents
				.filter { matches($0, query: query) }
				.map(VaultDeckItem.document)
		}
		return orderedDeckItems(items)
	}

	var hasArchivedItems: Bool {
		!cardDataStore.archivedCards.isEmpty || !documentDataStore.archivedDocuments.isEmpty
	}

	func loadItems() {
		isLoading = true
		defer { isLoading = false }

		let cardsLoaded = cardDataStore.loadCards()
		switch documentDataStore.loadDocuments() {
		case .success:
			loadingError = cardsLoaded ? nil : "Holder could not refresh cards. Your last visible items are still available."
		case .failure:
			loadingError = "Holder could not refresh documents. Your last visible items are still available."
		}
	}

	@discardableResult
	func archiveCard(_ card: CardData) -> Bool {
		cardDataStore.archiveCard(card)
	}

	@discardableResult
	func unarchiveCard(_ card: CardData) -> Bool {
		cardDataStore.unarchiveCard(card)
	}

	@discardableResult
	func deleteCard(_ card: CardData) -> Bool {
		cardDataStore.deleteCard(with: card.id)
	}

	@discardableResult
	func archiveDocument(_ document: DocumentData) -> Bool {
		do {
			try documentDataStore.archive(document)
			return true
		} catch {
			return false
		}
	}

	@discardableResult
	func unarchiveDocument(_ document: DocumentData) -> Bool {
		do {
			try documentDataStore.unarchive(document)
			return true
		} catch {
			return false
		}
	}

	@discardableResult
	func deleteDocument(_ document: DocumentData) -> Bool {
		do {
			try documentDataStore.delete(document)
			return true
		} catch {
			return false
		}
	}

	/// Marks a single active or archived deck item as a favorite after the
	/// corresponding store has persisted it. UI code can optimistically animate
	/// only after this returns `true`.
	@discardableResult
	func setFavorite(_ item: VaultDeckItem, isFavorite: Bool) -> Bool {
		switch item {
		case .card(let card):
			let succeeded = cardDataStore.setFavorite(cardID: card.id, isFavorite: isFavorite)
			if !succeeded {
				loadingError = cardDataStore.lastError?.errorDescription ?? "Holder could not save the card favorite."
			}
			return succeeded
		case .document(let document):
			do {
				try documentDataStore.setFavorite(documentID: document.id, isFavorite: isFavorite)
				return true
			} catch {
				loadingError = documentDataStore.lastError?.errorDescription ?? "Holder could not save the document favorite."
				return false
			}
		}
	}

	@discardableResult
	func toggleFavorite(_ item: VaultDeckItem) -> Bool {
		setFavorite(item, isFavorite: !item.isFavorite)
	}

	/// Saves a complete active deck order across cards and documents. Favorites
	/// remain a separate, higher-priority group; callers should pass the visual
	/// order within those groups. The two secure stores cannot share a Keychain
	/// transaction, so a second-store failure is reported while each store keeps
	/// its in-memory state aligned with the records it did save.
	@discardableResult
	func updateDeckOrder(_ orderedItems: [VaultDeckItem]) -> Bool {
		let activeItems = activeDeckItems
		let expectedIDs = Set(activeItems.map(\.id))
		let submittedIDs = orderedItems.map(\.id)
		guard submittedIDs.count == expectedIDs.count,
			Set(submittedIDs) == expectedIDs else {
			loadingError = "Holder could not save that deck order."
			return false
		}

		var orderedCards: [CardData] = []
		var orderedDocuments: [DocumentData] = []
		for (index, item) in orderedItems.enumerated() {
			switch item.destination {
			case .card(let id):
				guard var card = cardDataStore.findCard(by: id), !card.isArchived else {
					loadingError = "A card changed before Holder could save the deck order. Try again."
					return false
				}
				card.sortIndex = index
				orderedCards.append(card)
			case .document(let id):
				guard var document = documentDataStore.document(with: id), !document.isArchived else {
					loadingError = "A document changed before Holder could save the deck order. Try again."
					return false
				}
				document.sortIndex = index
				orderedDocuments.append(document)
			}
		}

		guard cardDataStore.updateDeckOrder(orderedCards) else {
			loadingError = cardDataStore.lastError?.errorDescription ?? "Holder could not save the card deck order."
			return false
		}

		do {
			try documentDataStore.updateDeckOrder(orderedDocuments)
			return true
		} catch {
			loadingError = "Holder saved card order, but could not finish saving document order. Try again."
			return false
		}
	}

	/// Handles a widget deep link (`holder://card/{uuid}`). Document data is not
	/// exposed to widgets and therefore has no matching deep-link route.
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
			if activeCards.isEmpty { _ = cardDataStore.loadCards() }
			await findAndSelectCard(by: cardID, onOpenedFromWidget: onOpenedFromWidget)
		}
	}

	private var normalizedSearchText: String {
		searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
	}

	/// Never searches card numbers, CVVs, expiry dates, or document fields.
	/// This keeps the home-search state useful without treating sensitive values
	/// as an indexable deck label.
	private func matches(_ card: CardData, query: String) -> Bool {
		guard !query.isEmpty else { return true }
		return [card.description, card.type.rawValue, card.network.rawValue]
			.contains { $0.lowercased().contains(query) }
	}

	private func matches(_ document: DocumentData, query: String) -> Bool {
		guard !query.isEmpty else { return true }
		return [document.title, document.kind.rawValue]
			.contains { $0.lowercased().contains(query) }
	}

	private var activeDeckItems: [VaultDeckItem] {
		activeCards.map(VaultDeckItem.card) + documentDataStore.documents.map(VaultDeckItem.document)
	}

	/// The persisted order is deliberately independent of names: changing a
	/// card label or document title never rearranges a person's deck. Legacy
	/// records remain deterministic through `VaultDeckItem.id` until reordered.
	private func orderedDeckItems(_ items: [VaultDeckItem]) -> [VaultDeckItem] {
		items.sorted { lhs, rhs in
			if lhs.isFavorite != rhs.isFavorite {
				return lhs.isFavorite
			}
			let lhsIndex = lhs.sortIndex ?? Int.max
			let rhsIndex = rhs.sortIndex ?? Int.max
			if lhsIndex != rhsIndex {
				return lhsIndex < rhsIndex
			}
			return lhs.id < rhs.id
		}
	}

	private func findAndSelectCard(
		by id: UUID,
		attempt: Int = 0,
		onOpenedFromWidget: (() -> Void)? = nil
	) async {
		guard !Task.isCancelled else { return }
		if cardDataStore.findCard(by: id) != nil {
			selectedItem = .card(id)
			onOpenedFromWidget?()
			return
		}
		guard attempt < 5 else { return }
		do {
			try await Task.sleep(nanoseconds: 50_000_000 * UInt64(1 << attempt))
		} catch {
			return
		}
		await findAndSelectCard(by: id, attempt: attempt + 1, onOpenedFromWidget: onOpenedFromWidget)
	}
}
