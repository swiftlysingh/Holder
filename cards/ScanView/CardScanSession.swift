//
//  CardScanSession.swift
//  cards
//
//  Applies a scan to CardData without wiping fields the user already entered.
//

import Foundation

enum CardScanSession {
	static func apply(_ result: CardScanResult, to card: inout CardData) {
		card.number = CardPAN.formatted(result.pan)
		if result.network != .other {
			card.network = result.network
		} else {
			card.network = CardPAN.network(for: result.pan)
		}

		if let expiry = result.expiry?.trimmingCharacters(in: .whitespacesAndNewlines), !expiry.isEmpty {
			card.expiration = expiry
		}

		if let name = result.cardholderName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
			card.name = name
		}
	}

	static func result(from observation: CardFrameObservation) -> CardScanResult? {
		guard let pan = observation.pan else { return nil }
		return CardScanResult(
			pan: pan,
			expiry: observation.expiry,
			cardholderName: observation.cardholderName,
			network: CardPAN.network(for: pan)
		)
	}

	static func lastFour(of pan: String) -> String {
		String(pan.suffix(4))
	}
}
