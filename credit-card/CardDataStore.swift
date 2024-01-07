//
//  CardDataStore.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 07/01/24.
//
import SwiftUI

@Observable
class CardDataStore {
	var cards: [CardData] = []

	init() {
		loadCards()
	}

	func loadCards() {
		let retrievedCard = retrieveAllCardData(service: Bundle.main.bundleIdentifier ?? "com.myApp.defaultService") ?? []
		cards = retrievedCard.sorted(by: { $0.type < $1.type })
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
			kSecAttrAccount as String: id.uuidString
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
			kSecAttrAccount as String: account
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
			kSecReturnData as String: kCFBooleanTrue!
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
}
