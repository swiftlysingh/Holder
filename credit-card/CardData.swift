//
//  CardData.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import Foundation
import SwiftData

struct CardData : Identifiable {
	var id: UUID
	var number : String
	var cvv : String
	var expiration : String
	var nickname : String
	var type : CardType
}

@Model
class PartCardData : Identifiable {
	var id: UUID
	var number: String
	var name : String
	var type : CardType

	init(card : CardData) {
		self.id = UUID()
		self.number = card.number.toSecureCard()
		self.name = card.nickname
		self.type = card.type
	}
}


enum CardType: String, CaseIterable, Identifiable, Codable {
	var id: Self {
		return self
	}

	case creditCard = "Credit Card"
	case debitCard = "Debit Card"
}
