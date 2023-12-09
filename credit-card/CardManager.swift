//
//  CardManager.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import Foundation

final class CardManager {

	static let standard = CardManager()
	private init() {}

	func save(_ card: CardData) {

		let partData = PartCardData(card: card)

		// Create query
		let query = [
			kSecValueData: card,
			kSecClass: kSecClassGenericPassword,
			kSecAttrService: "service",
			kSecAttrAccount: partData.id,
		] as CFDictionary

		// Add data in query to keychain
		let status = SecItemAdd(query, nil)

		if status != errSecSuccess {
			// Print out the error
			print("Error: \(status)")
		}
	}

}
