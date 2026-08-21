//
//  CardScanning.swift
//  cards
//
//  Engine boundary for Holder's on-device card scanning. Keeping the camera
//  lifecycle behind a protocol makes the app-owned flow testable.
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
	func makeCameraView() -> AnyView
	func scanUpdates() -> AsyncStream<CardScanUpdate>
	func verifyCurrentCandidate() async -> CardScanResult?
	func stop()
}

enum CardScanningEngineID {
	static let vision = "vision"
}

enum CardScanningEngineFactory {
	static var currentEngineID: String { CardScanningEngineID.vision }

	@MainActor
	static func make() -> any CardScanningEngine {
		#if os(iOS)
		VisionCardScanningEngine()
		#else
		UnavailableCardScanningEngine(engineID: CardScanningEngineID.vision)
		#endif
	}
}

@MainActor
final class UnavailableCardScanningEngine: CardScanningEngine {
	let engineID: String

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
