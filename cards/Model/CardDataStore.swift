//
//  CardDataStore.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 07/01/24.
//
import SwiftUI
import WidgetKit

enum CardDataStoreError: Error, LocalizedError, Equatable {
	case retrievalFailed
	case persistenceFailed
	case invalidDeckOrder
	case cardNotFound
	case legacyImageDeletionFailed

	var errorDescription: String? {
		switch self {
		case .retrievalFailed:
			return "Holder could not refresh cards."
		case .persistenceFailed:
			return "Holder could not save the card changes."
		case .invalidDeckOrder:
			return "Holder could not save that deck order."
		case .cardNotFound:
			return "That card is no longer available."
		case .legacyImageDeletionFailed:
			return "Holder could not remove the legacy card image."
		}
	}
}

@Observable
class CardDataStore {

	var cardsByType: [CardType: [CardData]] = [:]
	var archivedCards: [CardData] = []
	private(set) var lastError: CardDataStoreError?

	// MARK: - Widget Data Sharing

	private let appGroupID = "group.com.swiftlysingh.cards"
	private let widgetCardsKey = "widgetAvailableCards"
	private let debugFixturesInitializedKey = "debugFixturesInitialized"

	private var sharedDefaults: UserDefaults? {
		UserDefaults(suiteName: appGroupID)
	}

	private var isDebugOrSimulator = {
	#if DEBUG || BETA
		return true
	#else
		return false
	#endif
	}()

	/// Distinguishes confirmed empty Keychain results from Security failures.
	enum CardRetrievalKind: Equatable {
		case success
		case empty
		case failure
	}

	enum CardRetrievalResult {
		case success([CardData])
		case empty
		case failure
	}

	@ObservationIgnored
	private let retrieveCards: (String) -> CardRetrievalResult
	@ObservationIgnored
	private let deleteStoredCard: (UUID) -> Bool
	@ObservationIgnored
	private let deleteLegacyImage: (UUID) -> Bool
	@ObservationIgnored
	private let saveStoredCard: (CardData) -> Bool

	init(
		retrieveCards: ((String) -> CardRetrievalResult)? = nil,
		deleteStoredCard: ((UUID) -> Bool)? = nil,
		deleteLegacyImage: ((UUID) -> Bool)? = nil,
		saveStoredCard: ((CardData) -> Bool)? = nil
	) {
		self.retrieveCards = retrieveCards ?? Self.retrieveAllCardData
		self.deleteStoredCard = deleteStoredCard ?? Self.deleteStoredCardData
		self.deleteLegacyImage = deleteLegacyImage ?? { ICloudDataManager.shared.deleteImage(for: $0) }
		self.saveStoredCard = saveStoredCard ?? Self.saveOrUpdateCardData
		loadCards()
	}

	@discardableResult
	func loadCards() -> Bool {
		switch retrieveCards(Bundle.main.bundleIdentifier ?? "com.myApp.defaultService") {
		case .failure:
			// Preserve in-memory cards and widget snapshot on real Keychain/decode errors.
			lastError = .retrievalFailed
			return false
		case .empty:
			commitRetrievedCards([])
			lastError = nil
			return true
		case .success(let cards):
			commitRetrievedCards(cards)
			lastError = nil
			return true
		}
	}

	private func commitRetrievedCards(_ cards: [CardData]) {
		var retrievedCard = cards
		let hasInitializedDebugFixtures = UserDefaults.standard.bool(forKey: debugFixturesInitializedKey)

		#if DEBUG || BETA
		if Self.shouldSeedDebugFixtures(
			isDebugOrSimulator: isDebugOrSimulator,
			hasStoredCards: !retrievedCard.isEmpty,
			hasInitializedFixtures: hasInitializedDebugFixtures
		) {
			let fixtures = [
				CardData(id: UUID(), number: "4234567890123456", cvv: "123", expiration: "12/25", name: "John Doe", description: "Axis Visa", type: .creditCard, network: "4234567890123456".getCardNetwork()),
				CardData(id: UUID(), number: "5345678901234567", cvv: "234", expiration: "11/24", name: "Jane Smith", description: "SBI MasterCard", type: .creditCard, network: "5345678901234567".getCardNetwork()),
				CardData(id: UUID(), number: "34567890123456", cvv: "345", expiration: "10/23", name: "Alex Johnson", description: "American Express Gold", type: .creditCard, network: "34567890123456".getCardNetwork()),
				CardData(id: UUID(), number: "6067890123456789", cvv: "456", expiration: "08/26", name: "Emily Davis", description: "Kotak PVR", type: .debitCard, network: "6067890123456789".getCardNetwork()),
				CardData(
					id: UUID(),
					number: "3678901234567890",
					cvv: "567",
					expiration: "07/25",
					name: "Michael Brown",
					description: "HDFC Platinum",
					type: .debitCard,
					network: "3678901234567890".getCardNetwork()
				),
				CardData(
					id: UUID(),
					number: "3678901234567890",
					cvv: "567",
					expiration: "07/25",
					name: "Michael Brown",
					description: "HDFC Platinum",
					type: .otherCard,
					network: "3678901234567890".getCardNetwork()
				)
			]
			for fixture in fixtures {
				if saveStoredCard(fixture) {
					retrievedCard.append(fixture)
				}
			}
		}
		if isDebugOrSimulator && !hasInitializedDebugFixtures && !retrievedCard.isEmpty {
			UserDefaults.standard.set(true, forKey: debugFixturesInitializedKey)
		}
		#endif

		let partition = Self.partition(retrievedCard)
		cardsByType = partition.cardsByType
		archivedCards = partition.archivedCards
		syncCardsToWidget()
	}

	static func cardRetrievalKind(forStatus status: OSStatus) -> CardRetrievalKind {
		switch status {
		case errSecSuccess:
			return .success
		case errSecItemNotFound:
			return .empty
		default:
			return .failure
		}
	}

	/// Decodes every usable Keychain payload. A non-empty batch fails only when no
	/// records can be recovered, preserving existing in-memory state on total corruption.
	static func decodeAllCardData(from payloads: [Data?]) -> [CardData]? {
		var cards: [CardData] = []
		cards.reserveCapacity(payloads.count)
		var hadInvalidPayload = false
		for payload in payloads {
			guard let data = payload else {
				hadInvalidPayload = true
				continue
			}
			do {
				cards.append(try JSONDecoder().decode(CardData.self, from: data))
			} catch {
				hadInvalidPayload = true
			}
		}
		if cards.isEmpty && hadInvalidPayload {
			return nil
		}
		return cards
	}

	static func shouldSeedDebugFixtures(
		isDebugOrSimulator: Bool,
		hasStoredCards: Bool,
		hasInitializedFixtures: Bool
	) -> Bool {
		isDebugOrSimulator && !hasStoredCards && !hasInitializedFixtures
	}

	static func partition(_ cards: [CardData]) -> (cardsByType: [CardType: [CardData]], archivedCards: [CardData]) {
		let activeCards = deckOrdered(cards.filter { !$0.isArchived })
		let cardsByType = Dictionary(uniqueKeysWithValues: CardType.allCases.map { type in
			(type, activeCards.filter { $0.type == type })
		})
		return (cardsByType, deckOrdered(cards.filter { $0.isArchived }))
	}

	/// Shared ordering policy for every card surface. Older records have no
	/// `sortIndex`, so their UUID string supplies a deterministic fallback rather
	/// than letting Keychain iteration order or a title sort change the deck.
	static func deckOrdered(_ cards: [CardData]) -> [CardData] {
		cards.sorted { lhs, rhs in
			if lhs.isFavorite != rhs.isFavorite {
				return lhs.isFavorite
			}
			let lhsIndex = lhs.sortIndex ?? Int.max
			let rhsIndex = rhs.sortIndex ?? Int.max
			if lhsIndex != rhsIndex {
				return lhsIndex < rhsIndex
			}
			return lhs.id.uuidString < rhs.id.uuidString
		}
	}

	@discardableResult
	func addCard(_ card: CardData) -> Bool {
		updateCard(card)
	}

	/// Persists before mutating observable state so card editors and the deck
	/// never show a favorite or order value that did not reach Keychain.
	@discardableResult
	func updateCard(_ card: CardData) -> Bool {
		guard saveStoredCard(card) else {
			lastError = .persistenceFailed
			return false
		}
		commitPersistedCards([card])
		lastError = nil
		return true
	}

	@discardableResult
	func setFavorite(cardID: UUID, isFavorite: Bool) -> Bool {
		guard var card = findCard(by: cardID) else {
			lastError = .cardNotFound
			return false
		}
		card.isFavorite = isFavorite
		return updateCard(card)
	}

	/// Saves the supplied cards one at a time, updating observable state only
	/// after each durable write. Keychain has no multi-record transaction; if a
	/// later write fails, the successful prefix remains visible because it is the
	/// truthful persisted state, and `lastError` reports the incomplete reorder.
	@discardableResult
	func updateDeckOrder(_ orderedCards: [CardData]) -> Bool {
		let currentIDs = Set(allStoredCards.map(\.id))
		let orderedIDs = orderedCards.map(\.id)
		guard orderedIDs.count == Set(orderedIDs).count,
			orderedIDs.allSatisfy({ currentIDs.contains($0) }) else {
			lastError = .invalidDeckOrder
			return false
		}

		var persistedCards: [CardData] = []
		for card in orderedCards {
			guard saveStoredCard(card) else {
				commitPersistedCards(persistedCards)
				lastError = .persistenceFailed
				return false
			}
			persistedCards.append(card)
		}

		commitPersistedCards(persistedCards)
		lastError = nil
		return true
	}

	/// Finds a card by its UUID (used for deep linking from widgets)
	func findCard(by id: UUID) -> CardData? {
		for type in CardType.allCases {
			if let cards = cardsByType[type], let card = cards.first(where: { $0.id == id }) {
				return card
			}
		}
		return archivedCards.first { $0.id == id }
	}

	func deleteCard(with id: UUID) -> Bool {
		// Legacy Other Card images are plaintext iCloud files. Remove them before
		// metadata so a failed file deletion keeps a visible, retryable record.
		if let card = findCard(by: id),
			(card.hasLegacyImage == true || (card.type == .otherCard && card.hasLegacyImage == nil)),
		   !deleteLegacyImage(id) {
			lastError = .legacyImageDeletionFailed
			return false
		}

		// Remove the minimized App Group projection before Keychain metadata. If
		// Holder terminates between those writes, a widget may temporarily omit a
		// still-stored card, but it can never keep showing a card that was deleted.
		// A normal Keychain failure restores the observable deck and projection.
		let previousCardsByType = cardsByType
		let previousArchivedCards = archivedCards
		for type in CardType.allCases {
			cardsByType[type]?.removeAll { $0.id == id }
		}
		archivedCards.removeAll { $0.id == id }
		syncCardsToWidget()

		guard deleteStoredCard(id) else {
			cardsByType = previousCardsByType
			archivedCards = previousArchivedCards
			syncCardsToWidget()
			lastError = .persistenceFailed
			return false
		}

		lastError = nil
		return true
	}

	private static func deleteStoredCardData(with id: UUID) -> Bool {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.myApp.defaultService",
			kSecAttrAccount as String: id.uuidString,
			kSecAttrSynchronizable as String: kCFBooleanTrue!
		]

		let deletionStatus = SecItemDelete(query as CFDictionary)
		return deletionStatus == errSecSuccess || deletionStatus == errSecItemNotFound
	}

	// MARK: - Archive

	@discardableResult
	func archiveCard(_ card: CardData) -> Bool {
		var archivedCard = card
		archivedCard.isArchived = true
		return updateCard(archivedCard)
	}

	@discardableResult
	func unarchiveCard(_ card: CardData) -> Bool {
		var unarchivedCard = card
		unarchivedCard.isArchived = false
		return updateCard(unarchivedCard)
	}

	private var allStoredCards: [CardData] {
		CardType.allCases.flatMap { cardsByType[$0] ?? [] } + archivedCards
	}

	private func commitPersistedCards(_ replacements: [CardData]) {
		guard !replacements.isEmpty else { return }
		var currentCards = allStoredCards
		for replacement in replacements {
			currentCards.removeAll { $0.id == replacement.id }
			currentCards.append(replacement)
		}
		let partition = Self.partition(currentCards)
		cardsByType = partition.cardsByType
		archivedCards = partition.archivedCards
		syncCardsToWidget()
	}

	/// Returns whether the Keychain write succeeded.
	private static func saveOrUpdateCardData(_ cardData: CardData) -> Bool {
		let service = Bundle.main.bundleIdentifier ?? "com.myApp.defaultService"
		let account = cardData.id.uuidString

		// Convert CardData to Data
		guard let cardDataEncoded = try? JSONEncoder().encode(cardData) else {
			print("Failed to encode CardData")
			return false
		}

		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
			kSecAttrSynchronizable as String : kCFBooleanTrue!
		]

		// Check if item already exists
		let status = SecItemCopyMatching(query as CFDictionary, nil)

		if status == errSecItemNotFound {
			// Add a new item
			var newItem = query
			newItem[kSecValueData as String] = cardDataEncoded
			return SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess
		} else if status == errSecSuccess {
			// Update existing item
			let updateAttributes: [String: Any] = [kSecValueData as String: cardDataEncoded]

			return SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary) == errSecSuccess
		} else {
			// Handle other errors
			print("Error checking for existing Keychain item: \(status)")
			return false
		}
	}

	private static func retrieveAllCardData(service: String) -> CardRetrievalResult {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecMatchLimit as String: kSecMatchLimitAll,
			kSecReturnAttributes as String: kCFBooleanTrue!,
			kSecReturnData as String: kCFBooleanTrue!,
			kSecAttrSynchronizable as String: kCFBooleanTrue!
		]

		var items: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &items)

		switch Self.cardRetrievalKind(forStatus: status) {
		case .empty:
			print("No items found in the Keychain")
			return .empty
		case .failure:
			print("Error retrieving from Keychain: \(status)")
			return .failure
		case .success:
			break
		}

		guard let existingItems = items as? [[String: Any]] else {
			print("Error retrieving from Keychain: unexpected item payload")
			return .failure
		}

		let payloads = existingItems.map { $0[kSecValueData as String] as? Data }
		guard let cardDataArray = Self.decodeAllCardData(from: payloads) else {
			print("Error decoding CardData: missing or invalid Keychain payload")
			return .failure
		}
		if cardDataArray.count != payloads.count {
			print("Warning: skipped \(payloads.count - cardDataArray.count) invalid Keychain card payload(s)")
		}

		return .success(cardDataArray)
	}

	// MARK: - Widget Sync

	/// Syncs card data to widget via App Group (only safe display data, no sensitive info)
	func syncCardsToWidget() {
		let allCards = CardType.allCases.flatMap { cardsByType[$0] ?? [] }
		let widgetCards = allCards.map { card -> [String: Any] in
			return [
				"id": card.id.uuidString,
				"displayName": Self.widgetDisplayName(for: card),
				"lastFourDigits": Self.widgetLastFourDigits(for: card),
				"network": card.network.rawValue
			]
		}

		if let data = try? JSONSerialization.data(withJSONObject: widgetCards) {
			sharedDefaults?.set(data, forKey: widgetCardsKey)
		}
		WidgetCenter.shared.reloadAllTimelines()
	}

	/// `name` is the cardholder field, not a safe brand-label fallback for a widget.
	/// When no explicit card label exists, use the generic type instead.
	static func widgetDisplayName(for card: CardData) -> String {
		card.displayLabel
	}

	/// A widget tail is safe only when it hides at least one leading character.
	/// Short loyalty, travel, or Other Card identifiers are omitted rather than
	/// being copied in full into the App Group projection.
	static func widgetLastFourDigits(for card: CardData) -> String {
		let identifier = card.number.filter { !$0.isWhitespace }
		guard identifier.count > 4 else { return "" }
		return String(identifier.suffix(4))
	}

}
