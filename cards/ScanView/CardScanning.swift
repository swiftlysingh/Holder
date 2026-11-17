import SwiftUI

#if os(iOS)
import VisionKit
#endif

struct CardScanResult: Equatable, Sendable {
	var pan: String
	var expiry: String?
	var cardholderName: String?
	var network: CardNetwork

	var lastFour: String {
		String(pan.suffix(4))
	}
}

struct CardScanMetrics: Equatable, Sendable {
	var engine: String
	var timeToPANMs: Int?
	var timeToCompleteMs: Int
	var panSuccess: Bool
	var expirySuccess: Bool
	var holderSuccess: Bool
	var wasRescan: Bool
}

struct CardScanEndMetrics: Equatable, Sendable {
	enum Outcome: String, Sendable {
		case success
		case cancelled
		case manualEntry = "manual_entry"
		case permissionDenied = "permission_denied"
		case unsupported
		case cameraUnavailable = "camera_unavailable"
		case dismissed
	}

	var engine: String
	var outcome: Outcome
	var elapsedMs: Int
	var hadCandidate: Bool
	var timeToPANMs: Int?
	var torchOn: Bool
	var isRescan: Bool
	var attemptNumber: Int
	var backgrounded = false

	var reason: String {
		switch outcome {
		case .success: "verified_pan"
		case .cancelled: "cancel_button"
		case .manualEntry: "manual_entry_button"
		case .permissionDenied: "camera_permission_denied"
		case .unsupported: "scanner_unsupported"
		case .cameraUnavailable: "camera_unavailable"
		case .dismissed: backgrounded ? "backgrounded" : "view_disappeared"
		}
	}
}

struct CardScanRetryMetrics: Equatable, Sendable {
	var engine: String
	var elapsedMs: Int
	var hadCandidate: Bool
	var isRescan: Bool
	var attemptNumber: Int
}

enum CardScanUpdate: Sendable {
	case permissionDenied
	case unsupported(String)
	case scanning(guidance: String)
	case candidate(lastFour: String, network: CardNetwork)
	case retryableFailure(String)
	case verified(CardScanResult)
	case failed(String)
}

@MainActor
protocol CardScanningEngine: AnyObject {
	var engineID: String { get }
	var isTorchAvailable: Bool { get }
	func makeCameraView() -> AnyView
	func scanUpdates() -> AsyncStream<CardScanUpdate>
	func verifyCurrentCandidate() async -> CardScanResult?
	@discardableResult func setTorchEnabled(_ isEnabled: Bool) -> Bool
	func stop()
}

extension CardScanningEngine {
	var isTorchAvailable: Bool { false }

	@discardableResult
	func setTorchEnabled(_ isEnabled: Bool) -> Bool { false }
}

enum CardScanningEngineID {
	static let vision = "vision"
}

enum CardScanningEngineFactory {
	static var currentEngineID: String { CardScanningEngineID.vision }

	@MainActor
	static var isScanningAvailable: Bool {
		#if os(iOS)
		#if DEBUG
		if ProcessInfo.processInfo.arguments.contains("-holderShowScannerOnboarding") {
			return true
		}
		#endif
		return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
		#else
		return false
		#endif
	}

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
