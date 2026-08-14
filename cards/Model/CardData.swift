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
	/// A user-controlled deck position shared with documents. `nil` is the
	/// deterministic legacy value; the deck falls back to the record identifier
	/// until the user explicitly reorders it.
	var sortIndex: Int?
	/// Favorites stay at the front of the deck without changing the card's
	/// archived state or sensitive fields.
	var isFavorite: Bool
	/// An optional visual choice only. Keeping it optional preserves every
	/// existing card payload exactly as a card record, with no migration step.
	var palette: CardPalette?
	/// `nil` means a pre-redesign Other Card whose iCloud image state is unknown.
	/// `true` can also be a conservative cleanup marker on another card type after
	/// an interrupted legacy-image edit, so deletion retries iCloud before metadata.
	var hasLegacyImage: Bool?

	/// A non-personal label safe for masked deck, archive, and widget surfaces.
	/// `name` is the cardholder name and must never be used as a fallback here.
	var displayLabel: String {
		let label = description.trimmingCharacters(in: .whitespacesAndNewlines)
		return label.isEmpty ? type.rawValue : label
	}

	private enum CodingKeys: String, CodingKey {
		case id, number, cvv, expiration, name, description, type, network, isArchived, sortIndex, isFavorite, palette, hasLegacyImage
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
		isArchived: Bool = false,
		sortIndex: Int? = nil,
		isFavorite: Bool = false,
		palette: CardPalette? = nil,
		hasLegacyImage: Bool? = nil
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
		self.sortIndex = sortIndex
		self.isFavorite = isFavorite
		self.palette = palette
		self.hasLegacyImage = hasLegacyImage
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
			isArchived: try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false,
			sortIndex: try container.decodeIfPresent(Int.self, forKey: .sortIndex),
			isFavorite: try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false,
			palette: try container.decodeIfPresent(CardPalette.self, forKey: .palette),
			hasLegacyImage: try container.decodeIfPresent(Bool.self, forKey: .hasLegacyImage)
		)
	}

}

enum CardType: String, CaseIterable, Identifiable, Codable {
	var id: Self {
		return self
	}

	case creditCard = "Credit Card"
	case debitCard = "Debit Card"
	case otherCard = "Other Card"
	case loyaltyCard = "Loyalty Card"
	case travelCard = "Travel Card"

	static func < (lhs: CardType, rhs: CardType) -> Bool {
		// credit card
		// debit card
		return lhs.rawValue < rhs.rawValue
	}

}

/// A deliberately small, deterministic palette shared by the card and document
/// deck. The value is presentation metadata; it never changes how sensitive
/// card or document data is persisted.
enum CardPalette: String, CaseIterable, Identifiable, Codable, Hashable {
	case emerald
	case forest
	case ink
	case berry
	case amber

	var id: Self { self }
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
