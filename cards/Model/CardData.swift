//
//  CardData.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import Foundation

struct CardData : Identifiable, Codable {
	var id: UUID
	var number : String
	var cvv : String
	var expiration : String
	var name : String
    var description: String
	var type : CardType
}

enum CardType: String, CaseIterable, Identifiable, Codable {
	var id: Self {
		return self
	}

	case creditCard = "Credit Card"
	case debitCard = "Debit Card"

	static func < (lhs: CardType, rhs: CardType) -> Bool {
		// credit card
		// debit card
		return lhs.rawValue < rhs.rawValue
	}

}

extension CardData {
	func toData() throws -> Data {
		let encoder = JSONEncoder()
		return try encoder.encode(self)
	}
}
