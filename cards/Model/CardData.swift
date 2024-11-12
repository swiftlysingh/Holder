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

	init(
		id: UUID,
		number: String,
		cvv: String,
		expiration: String,
		name: String,
		description: String,
		type: CardType,
		network: CardNetwork = .other
	) {
		self.id = id
		
		// Format card number based on number length
		let cleanNumber = number.replacingOccurrences(of: " ", with: "")
		if cleanNumber.count == 15 {
			// Format as XXXX XXXXXX XXXXX for 15-digit cards (like Amex)
			let chunks = [
			cleanNumber.prefix(4),
			cleanNumber.dropFirst(4).prefix(6),
			cleanNumber.dropFirst(10)
			].compactMap { String($0) }
			self.number = chunks.joined(separator: " ")
		} else {
			// Format as XXXX XXXX XXXX XXXX for 16-digit cards
			let chunks = stride(from: 0, to: cleanNumber.count, by: 4).map {
			let start = cleanNumber.index(cleanNumber.startIndex, offsetBy: $0)
			let end = cleanNumber.index(start, offsetBy: min(4, cleanNumber.count - $0))
			return String(cleanNumber[start..<end])
			}
			self.number = chunks.joined(separator: " ")
		}
		
		self.cvv = cvv
		self.expiration = expiration
		self.name = name
		self.description = description
		self.type = type
		self.network = network
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
	case otherCard = "Other Card"

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
    case rupay = "Rupay"
	case other = "Unknown"

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
		return CardData(
			id: id,
			number: number,
			cvv: cvv,
			expiration: expiration,
			name: name,
			description: description,
			type: type,
			network: number.getCardNetwork()
		)
	}
}
