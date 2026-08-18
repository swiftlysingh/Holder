//
//  CardScanning.swift
//  cards
//
//  Engine boundary for on-device card scanning. UI talks to this protocol
//  so Vision, BlinkCard, and Scanbot can be swapped without rewriting the flow.
//

import SwiftUI

/// Recognized payment-card fields. PAN is required; expiry and name are best-effort.
struct CardScanResult: Equatable, Sendable {
	var pan: String
	var expiry: String?
	var cardholderName: String?
	var network: CardNetwork

	var lastFour: String {
		String(pan.suffix(4))
	}
}

/// Non-sensitive scan timing used for analytics. Never include PAN, name, expiry, CVV, OCR, or images.
struct CardScanMetrics: Equatable, Sendable {
	var engine: String
	var timeToPANMs: Int?
	var timeToCompleteMs: Int
	var panSuccess: Bool
	var expirySuccess: Bool
	var holderSuccess: Bool
	var wasRescan: Bool
}

enum CardScanUpdate: Sendable {
	case permissionDenied
	case unsupported(String)
	case scanning(guidance: String)
	case candidate(lastFour: String, network: CardNetwork)
	case verified(CardScanResult)
	case failed(String)
}

@MainActor
protocol CardScanningEngine: AnyObject {
	var engineID: String { get }
	var showsCustomOverlay: Bool { get }
	func makeCameraView() -> AnyView
	func scanUpdates() -> AsyncStream<CardScanUpdate>
	func verifyCurrentCandidate() async -> CardScanResult?
	func stop()
}

enum CardScanningEngineID {
	static let vision = "vision"
	static let blinkCard = "blinkcard"
	static let scanbot = "scanbot"
}

enum CardScanningEngineFactory {
	static var currentEngineID: String { CardScanningEngineID.blinkCard }

	@MainActor
	static func make() -> any CardScanningEngine {
		#if os(iOS)
		BlinkCardScanningEngine()
		#else
		UnavailableCardScanningEngine(engineID: CardScanningEngineID.blinkCard)
		#endif
	}
}

@MainActor
final class UnavailableCardScanningEngine: CardScanningEngine {
	let engineID: String
	let showsCustomOverlay = false

	init(engineID: String) {
		self.engineID = engineID
	}

	func makeCameraView() -> AnyView {
		AnyView(EmptyView())
	}

	func scanUpdates() -> AsyncStream<CardScanUpdate> {
		AsyncStream { continuation in
			continuation.yield(.unsupported("Card scanning is available on iPhone and iPad."))
			continuation.finish()
		}
	}

	func verifyCurrentCandidate() async -> CardScanResult? { nil }

	func stop() {}
}
