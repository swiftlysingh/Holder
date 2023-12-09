//
//  CardData.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import Foundation

struct CardData : Identifiable{
	var id: UUID
	var number : String
	var cvv : String
	var expiration : String
	var nickname : String
	var type : CardType
}

struct PartCardData : Identifiable{
	var id: UUID
	var number: String
	var name : String
	var type : CardType
}


enum CardType: String, CaseIterable, Identifiable {
	var id: Self {
		return self
	}

	case creditCard = "Credit Card"
	case debitCard = "Debit Card"
}
