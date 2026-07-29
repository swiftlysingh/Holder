//
//  CardDataStore.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 07/01/24.
//
import SwiftUI
import WidgetKit

@Observable
class CardDataStore {

	var cardsByType: [CardType: [CardData]] = [:]
	var archivedCards: [CardData] = []

	// MARK: - Widget Data Sharing

	private let appGroupID = "group.com.swiftlysingh.cards"
	private let widgetCardsKey = "widgetAvailableCards"

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

	init(retrieveCards: ((String) -> CardRetrievalResult)? = nil) {
		self.retrieveCards = retrieveCards ?? Self.retrieveAllCardData
		loadCards()
	}

	@discardableResult
	func loadCards() -> Bool {
		switch retrieveCards(Bundle.main.bundleIdentifier ?? "com.myApp.defaultService") {
		case .failure:
			// Preserve in-memory cards and widget snapshot on real Keychain/decode errors.
			return false
		case .empty:
			commitRetrievedCards([])
			return true
		case .success(let cards):
			commitRetrievedCards(cards)
			return true
		}
	}

	private func commitRetrievedCards(_ cards: [CardData]) {
		var retrievedCard = cards

		// Add default data for simulator / debug only when Keychain is confirmed empty.
		if isDebugOrSimulator && retrievedCard.isEmpty {
			retrievedCard.append(
				contentsOf: [
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
			)
		}

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

	static func partition(_ cards: [CardData]) -> (cardsByType: [CardType: [CardData]], archivedCards: [CardData]) {
		let activeCards = cards.filter { !$0.isArchived }
		let cardsByType = Dictionary(uniqueKeysWithValues: CardType.allCases.map { type in
			(type, activeCards.filter { $0.type == type })
		})
		return (cardsByType, cards.filter { $0.isArchived })
	}

	func addCard(_ card: CardData) {
		guard saveOrUpdateCardData(card) else {
			print("Failed to save card: \(card.id)")
			return
		}
		loadCards()
	}

	/// Finds a card by its UUID (used for deep linking from widgets)
	func findCard(by id: UUID) -> CardData? {
		for type in CardType.allCases {
			if let cards = cardsByType[type], let card = cards.first(where: { $0.id == id }) {
				return card
			}
		}
		return nil
	}

	func deleteCard(with id: UUID) -> Bool {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.myApp.defaultService",
			kSecAttrAccount as String: id.uuidString,
			kSecAttrSynchronizable as String: kCFBooleanTrue!
		]

		let status = SecItemDelete(query as CFDictionary)
		guard status == errSecSuccess else { return false }

		for type in CardType.allCases {
			cardsByType[type]?.removeAll { $0.id == id }
		}
		archivedCards.removeAll { $0.id == id }
		syncCardsToWidget()
		return true
	}

	// MARK: - Archive

	func archiveCard(_ card: CardData) {
		var archivedCard = card
		archivedCard.isArchived = true
		guard saveOrUpdateCardData(archivedCard) else {
			print("Failed to archive card: \(card.id)")
			return
		}
		loadCards()
	}

	func unarchiveCard(_ card: CardData) {
		var unarchivedCard = card
		unarchivedCard.isArchived = false
		guard saveOrUpdateCardData(unarchivedCard) else {
			print("Failed to unarchive card: \(card.id)")
			return
		}
		loadCards()
	}
/// Returns if success
	private func saveOrUpdateCardData(_ cardData: CardData) -> Bool {
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
			let cleanNumber = card.number.replacingOccurrences(of: " ", with: "")
			let lastFour = String(cleanNumber.suffix(4))
			let displayName = card.description.isEmpty ? card.name : card.description
			return [
				"id": card.id.uuidString,
				"displayName": displayName,
				"lastFourDigits": lastFour,
				"cardType": card.type.rawValue,
				"network": card.network.rawValue
			]
		}

		if let data = try? JSONSerialization.data(withJSONObject: widgetCards) {
			sharedDefaults?.set(data, forKey: widgetCardsKey)
		}
		WidgetCenter.shared.reloadAllTimelines()
	}

}
