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
	var isArchived: Bool

	private enum CodingKeys: String, CodingKey {
		case id, number, cvv, expiration, name, description, type, network, isArchived
	}

	init(
		id: UUID,
		number: String,
		cvv: String,
		expiration: String,
		name: String,
		description: String,
		type: CardType,
		network: CardNetwork = .other,
		isArchived: Bool = false
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
		self.isArchived = isArchived
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let number = try container.decode(String.self, forKey: .number)

		self.init(
			id: try container.decode(UUID.self, forKey: .id),
			number: number,
			cvv: try container.decode(String.self, forKey: .cvv),
			expiration: try container.decode(String.self, forKey: .expiration),
			name: try container.decode(String.self, forKey: .name),
			description: try container.decode(String.self, forKey: .description),
			type: try container.decode(CardType.self, forKey: .type),
			network: try container.decodeIfPresent(CardNetwork.self, forKey: .network) ?? number.getCardNetwork(),
			isArchived: try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
		)
	}

	func toShareString(includeSecurityCode: Bool) -> String {
		var details = "Name: \(name) \nNumber: \(number) \nExpiration: \(expiration)"
		if includeSecurityCode {
			details += " \nSecurity Code: \(cvv)"
		}
		return details
	}
}

enum CardType: String, CaseIterable, Identifiable, Codable {
	var id: Self {
		return self
	}

	case credit = "Credit"
	case debit = "Debit"
	case other = "Other"

	static func < (lhs: CardType, rhs: CardType) -> Bool {
		return lhs.rawValue < rhs.rawValue
	}

	init(from decoder: Decoder) throws {
		let raw = try decoder.singleValueContainer().decode(String.self)
		switch raw {
		// Legacy values persisted before the "Card" suffix was dropped
		case "Credit Card": self = .credit
		case "Debit Card": self = .debit
		case "Other Card": self = .other
		default:
			guard let type = CardType(rawValue: raw) else {
				throw DecodingError.dataCorrupted(DecodingError.Context(
					codingPath: decoder.codingPath,
					debugDescription: "Unknown card type: \(raw)"
				))
			}
			self = type
		}
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
    case discover = "Discover"
    case jcb = "JCB"
    case unionPay = "UnionPay"
	case other = "Unknown"

}

extension CardData {
	func toData() throws -> Data {
		let encoder = JSONEncoder()
		return try encoder.encode(self)
	}
}
