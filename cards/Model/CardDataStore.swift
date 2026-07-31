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

	init() {
		loadCards()
	}

	func loadCards() {
		var retrievedCard = retrieveAllCardData(service: Bundle.main.bundleIdentifier ?? "com.myApp.defaultService") ?? []
		let hasInitializedDebugFixtures = UserDefaults.standard.bool(forKey: debugFixturesInitializedKey)

			//		Add default data for simulator
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
				if saveOrUpdateCardData(fixture) {
					retrievedCard.append(fixture)
				}
			}
		}
		if isDebugOrSimulator && !hasInitializedDebugFixtures && !retrievedCard.isEmpty {
			UserDefaults.standard.set(true, forKey: debugFixturesInitializedKey)
		}
		let partition = Self.partition(retrievedCard)
		cardsByType = partition.cardsByType
		archivedCards = partition.archivedCards
		syncCardsToWidget()
	}

	static func shouldSeedDebugFixtures(
		isDebugOrSimulator: Bool,
		hasStoredCards: Bool,
		hasInitializedFixtures: Bool
	) -> Bool {
		isDebugOrSimulator && !hasStoredCards && !hasInitializedFixtures
	}

	static func partition(_ cards: [CardData]) -> (cardsByType: [CardType: [CardData]], archivedCards: [CardData]) {
		let activeCards = cards.filter { !$0.isArchived }
		let cardsByType = Dictionary(uniqueKeysWithValues: CardType.allCases.map { type in
			(type, activeCards.filter { $0.type == type })
		})
		return (cardsByType, cards.filter { $0.isArchived })
	}

	@discardableResult
	func addCard(_ card: CardData) -> Bool {
		let succeeded = saveOrUpdateCardData(card)
		if succeeded {
			loadCards()
		}
		return succeeded
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

		guard SecItemDelete(query as CFDictionary) == errSecSuccess else {
			return false
		}

		// Drop in-memory copies before widget sync so timelines match persistence.
		for type in CardType.allCases {
			cardsByType[type]?.removeAll { $0.id == id }
		}
		archivedCards.removeAll { $0.id == id }
		syncCardsToWidget()
		return true
	}

	// MARK: - Archive

	@discardableResult
	func archiveCard(_ card: CardData) -> Bool {
		var archivedCard = card
		archivedCard.isArchived = true
		guard saveOrUpdateCardData(archivedCard) else {
			print("Failed to archive card: \(card.id)")
			return false
		}
		loadCards()
		return true
	}

	@discardableResult
	func unarchiveCard(_ card: CardData) -> Bool {
		var unarchivedCard = card
		unarchivedCard.isArchived = false
		guard saveOrUpdateCardData(unarchivedCard) else {
			print("Failed to unarchive card: \(card.id)")
			return false
		}
		loadCards()
		return true
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

	private func retrieveAllCardData(service: String) -> [CardData]? {
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

		guard status == errSecSuccess else {
			print("Error retrieving from Keychain: \(status)")
			return nil
		}

		guard let existingItems = items as? [[String: Any]] else {
			print("No items found in the Keychain")
			return nil
		}

		var cardDataArray = [CardData]()

		for item in existingItems {

			if let data = item[kSecValueData as String] as? Data {
				do {
					let cardData = try JSONDecoder().decode(CardData.self, from: data)
					cardDataArray.append(cardData)
				} catch {
					print("Error decoding CardData: \(error)")
					// Optionally handle the error, e.g., continue with next item
				}
			}
		}
		return cardDataArray
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
