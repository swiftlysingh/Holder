//
//  CardDataStore.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 07/01/24.
//
import SwiftUI

@Observable
class CardDataStore {

	var cardsByType: [CardType: [CardData]] = [:]

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
		migrateOldEntriesforiCloud(for: Bundle.main.bundleIdentifier ?? "com.myApp.defaultService")
		var retrievedCard = retrieveAllCardData(service: Bundle.main.bundleIdentifier ?? "com.myApp.defaultService") ?? []

//		Add default data for simulator
		if isDebugOrSimulator && retrievedCard.isEmpty {
			retrievedCard.append(contentsOf: [
				CardData(id: UUID(), number: "1234567890123456", cvv: "123", expiration: "12/25", name: "John Doe", description: "Axis Visa", type: .creditCard),
				CardData(id: UUID(), number: "2345678901234567", cvv: "234", expiration: "11/24", name: "Jane Smith", description: "SBI MasterCard", type: .creditCard),
				CardData(id: UUID(), number: "34567890123456", cvv: "345", expiration: "10/23", name: "Alex Johnson", description: "American Express Gold", type: .creditCard),
				CardData(id: UUID(), number: "4567890123456789", cvv: "456", expiration: "08/26", name: "Emily Davis", description: "Kotak PVR", type: .debitCard),
				CardData(id: UUID(), number: "5678901234567890", cvv: "567", expiration: "07/25", name: "Michael Brown", description: "HDFC Platinum", type: .debitCard)
			])

		}
		for type in CardType.allCases {
			cardsByType[type] = retrievedCard.filter { $0.type == type }
		}
	}

	func addCard(_ card: CardData) {
		//TODO: Add error handling here
		_ = saveOrUpdateCardData(card)
		loadCards()
	}

	func deleteCard(with id: UUID) -> Bool {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.myApp.defaultService",
			kSecAttrAccount as String: id.uuidString,
			kSecAttrSynchronizable as String: kCFBooleanTrue!
		]

		let status = SecItemDelete(query as CFDictionary)

		return status == errSecSuccess
	}

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

	private func migrateOldEntriesforiCloud(for service: String) {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecMatchLimit as String: kSecMatchLimitAll,
			kSecReturnAttributes as String: kCFBooleanTrue as Any,
			kSecReturnData as String: kCFBooleanTrue as Any,
			kSecAttrSynchronizable as String: kCFBooleanFalse as Any // Look for non-synchronizable items
		]

		var items: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &items)

		guard status == errSecSuccess, let existingItems = items as? [[String: Any]] else {
			print("Error retrieving from Keychain for migration: \(status)")
			return
		}

		for item in existingItems {
			guard let account = item[kSecAttrAccount as String] as? String else {
				continue
			}

			let uniqueQuery: [String: Any] = [
				kSecClass as String: kSecClassGenericPassword,
				kSecAttrService as String: service,
				kSecAttrAccount as String: account,
				kSecAttrSynchronizable as String: kCFBooleanFalse as Any // Specify non-synchronizable to match the item
			]

			let updateAttributes: [String: Any] = [kSecAttrSynchronizable as String: kCFBooleanTrue as Any]

			let updateStatus = SecItemUpdate(uniqueQuery as CFDictionary, updateAttributes as CFDictionary)
			if updateStatus != errSecSuccess {
				print("Failed to migrate item for iCloud: \(updateStatus)")
			}
		}
	}
}
