//
//  CardData.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import Foundation

struct CardData : Identifiable, Codable, Hashable {
	var id: UUID
	var number : String
	var cvv : String
	var expiration : String
	var name : String
    var description: String
	var type : CardType
	var network: CardNetwork

	init(id: UUID, number: String, cvv: String, expiration: String, name: String, description: String, type: CardType, network: CardNetwork? = nil) {
		self.id = id
		self.number = number
		self.cvv = cvv
		self.expiration = expiration
		self.name = name
		self.description = description
		self.type = type
		self.network = network ?? number.getCardNetwork()
	}
	func toShareString() -> String {
		return "Name: \(self.name) \nNumber: \(number) \nExpiration: \(expiration) \nSecurity Code: \(cvv)"
	}
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

enum CardNetwork: String, CaseIterable, Identifiable, Codable {
	var id: Self {
		return self
	}

	case visa = "Visa"
	case master = "Mastercard"
	case amex = "Amex"
	case diners = "Diners"
	case other = "Other"

}

extension CardData {
	func toData() throws -> Data {
		let encoder = JSONEncoder()
		return try encoder.encode(self)
	}
}

struct OldCardData : Identifiable, Codable, Hashable {
	var id: UUID
	var number : String
	var cvv : String
	var expiration : String
	var name : String
	var description: String
	var type : CardType

	func transferToNewSchema() -> CardData {
		return CardData(id: id, number: number, cvv: cvv, expiration: expiration, name: name, description: description, type: type)
	}
}
