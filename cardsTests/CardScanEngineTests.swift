import CoreGraphics
import XCTest
@testable import Holder

#if os(iOS)
import SwiftUI
#endif

#if os(iOS)
final class CardScannerLayoutTests: XCTestCase {
	func testRejectsEmptyOrTinyBoundsThatWouldAbortVisionKit() {
		XCTAssertNil(CardScannerLayout.regionOfInterest(in: .zero))
		XCTAssertNil(CardScannerLayout.regionOfInterest(in: CGRect(x: 0, y: 0, width: 8, height: 430)))
		XCTAssertNil(CardScannerLayout.regionOfInterest(in: CGRect(x: 0, y: 0, width: 390, height: 8)))
		XCTAssertNil(CardScannerLayout.regionOfInterest(in: CGRect(
			x: 0,
			y: 0,
			width: CGFloat.nan,
			height: 430
		)))
	}

	func testReturnsAGuideInsideTypicalAddCardSheetBounds() {
		let bounds = CGRect(x: 0, y: 0, width: 390, height: 430)
		guard let roi = CardScannerLayout.regionOfInterest(in: bounds) else {
			return XCTFail("Expected a region of interest for a laid-out add-card sheet")
		}

		XCTAssertGreaterThanOrEqual(roi.width, CardScannerLayout.minimumRegionWidth)
		XCTAssertGreaterThanOrEqual(roi.height, CardScannerLayout.minimumRegionHeight)
		XCTAssertTrue(bounds.insetBy(dx: -0.5, dy: -0.5).contains(roi))
		XCTAssertEqual(roi, CardScannerLayout.guideFrame(in: bounds))
	}

	func testIgnoresSubpixelRegionDrift() {
		let lhs = CGRect(x: 52.1, y: 120.2, width: 286.4, height: 180.6)
		let rhs = CGRect(x: 52.3, y: 120.4, width: 286.2, height: 180.4)
		XCTAssertTrue(CardScannerLayout.isSameRegion(lhs, as: rhs))
		XCTAssertFalse(CardScannerLayout.isSameRegion(lhs, as: lhs.offsetBy(dx: 8, dy: 0)))
	}
}

@MainActor
final class CardScannerTorchTests: XCTestCase {
	func testTorchToggleAndScannerStopTurnTorchOff() {
		let engine = TorchSpyCardScanningEngine()
		let model = CardScannerViewModel(isRescan: false, engine: engine)

		XCTAssertTrue(model.isTorchAvailable)
		XCTAssertFalse(model.isTorchOn)

		model.toggleTorch()
		XCTAssertTrue(model.isTorchOn)
		XCTAssertEqual(engine.torchRequests, [true])

		model.stop()
		XCTAssertFalse(model.isTorchOn)
		XCTAssertEqual(engine.torchRequests, [true, false])
		XCTAssertTrue(engine.didStop)
	}
}

@MainActor
private final class TorchSpyCardScanningEngine: CardScanningEngine {
	let engineID = "torch-spy"
	let isTorchAvailable = true
	var torchRequests: [Bool] = []
	var didStop = false

	func makeCameraView() -> AnyView { AnyView(EmptyView()) }
	func scanUpdates() -> AsyncStream<CardScanUpdate> { AsyncStream { $0.finish() } }
	func verifyCurrentCandidate() async -> CardScanResult? { nil }

	func setTorchEnabled(_ isEnabled: Bool) -> Bool {
		torchRequests.append(isEnabled)
		return isEnabled
	}

	func stop() {
		didStop = true
	}
}
#endif

@MainActor
final class CardScanSessionTests: XCTestCase {
	func testScanAttemptDoesNotCarryMetadataAcrossPANs() {
		var attempt = CardScanAttempt()
		attempt.record(CardFrameObservation(
			pan: "4111111111111111",
			expiry: "12/30",
			cardholderName: "JANE DOE"
		))

		attempt.record(CardFrameObservation(
			pan: "5555555555554444",
			expiry: nil,
			cardholderName: nil
		))

		XCTAssertEqual(attempt.latestObservation.pan, "5555555555554444")
		XCTAssertNil(attempt.latestObservation.expiry)
		XCTAssertNil(attempt.latestObservation.cardholderName)
	}

	func testScanAttemptMergesMetadataOnlyFramesForTheCurrentPAN() {
		var attempt = CardScanAttempt()
		attempt.record(CardFrameObservation(
			pan: "4111111111111111",
			expiry: nil,
			cardholderName: nil
		))
		attempt.record(CardFrameObservation(
			pan: nil,
			expiry: "12/30",
			cardholderName: "JANE DOE"
		))

		XCTAssertEqual(attempt.latestObservation.pan, "4111111111111111")
		XCTAssertEqual(attempt.latestObservation.expiry, "12/30")
		XCTAssertEqual(attempt.latestObservation.cardholderName, "JANE DOE")
	}

	func testScanAttemptResetDropsMetadataFromFailedCandidate() {
		var attempt = CardScanAttempt()
		attempt.record(CardFrameObservation(
			pan: "4111111111111111",
			expiry: "12/30",
			cardholderName: "JANE DOE"
		))

		attempt.reset()

		XCTAssertEqual(attempt.latestObservation, CardFrameObservation())
	}

	func testApplyScanFillsPANAndNetwork() {
		var card = makeBlankCard()
		let result = CardScanResult(
			pan: "4111111111111111",
			expiry: "12/30",
			cardholderName: "JANE DOE",
			network: .visa
		)

		CardScanSession.apply(result, to: &card)

		XCTAssertEqual(card.number, "4111 1111 1111 1111")
		XCTAssertEqual(card.expiration, "12/30")
		XCTAssertEqual(card.name, "JANE DOE")
		XCTAssertEqual(card.network, .visa)
	}

	func testMissingExpiryAndNameDoNotEraseExistingValues() {
		var card = makeBlankCard()
		card.expiration = "11/29"
		card.name = "EXISTING NAME"

		CardScanSession.apply(
			CardScanResult(pan: "5555555555554444", expiry: nil, cardholderName: "", network: .master),
			to: &card
		)

		XCTAssertEqual(card.number, "5555 5555 5555 4444")
		XCTAssertEqual(card.expiration, "11/29")
		XCTAssertEqual(card.name, "EXISTING NAME")
		XCTAssertEqual(card.network, .master)
	}

	func testCardViewModelApplyScanLeavesManualFieldsIntact() {
		let model = CardViewModel(
			card: CardData(
				id: UUID(),
				number: "",
				cvv: "999",
				expiration: "08/29",
				name: "KEPT NAME",
				description: "Wallet",
				type: .credit
			),
			isEditing: true,
			addNewFlow: true,
			addUpdateCard: { _ in true }
		)
		model.selectedCardType = .debit

		model.applyScan(
			CardScanResult(pan: "378282246310005", expiry: nil, cardholderName: nil, network: .amex)
		)

		XCTAssertEqual(model.card.number, "3782 822463 10005")
		XCTAssertEqual(model.card.network, .amex)
		XCTAssertEqual(model.card.expiration, "08/29")
		XCTAssertEqual(model.card.name, "KEPT NAME")
		XCTAssertEqual(model.card.cvv, "999")
		XCTAssertEqual(model.card.description, "Wallet")
		XCTAssertEqual(model.selectedCardType, .debit)
		XCTAssertEqual(model.card.type, .debit)
		XCTAssertTrue(model.didUseScanner)
		XCTAssertFalse(model.isShowingScanner)
	}

	func testAddNewCardStartsWithoutSelectedType() {
		let model = CardViewModel(
			card: CardData(
				id: UUID(),
				number: "",
				cvv: "",
				expiration: "",
				name: "",
				description: "",
				type: .credit
			),
			isEditing: true,
			addNewFlow: true,
			addUpdateCard: { _ in true }
		)
		XCTAssertNil(model.selectedCardType)
		XCTAssertFalse(model.canFinishEditing)
	}

	func testScanDoesNotGuessAnUnselectedCardType() {
		let model = CardViewModel(
			card: makeBlankCard(),
			isEditing: true,
			addNewFlow: true,
			addUpdateCard: { _ in true }
		)

		model.applyScan(
			CardScanResult(
				pan: "4111111111111111",
				expiry: "12/30",
				cardholderName: "JANE DOE",
				network: .visa
			)
		)

		XCTAssertNil(model.selectedCardType)
		XCTAssertEqual(model.card.network, .visa)
		XCTAssertFalse(model.canFinishEditing)

		model.selectedCardType = .credit

		XCTAssertTrue(model.canFinishEditing)
		XCTAssertEqual(model.card.type, .credit)
	}
	private func makeBlankCard() -> CardData {
		CardData(
			id: UUID(),
			number: "",
			cvv: "",
			expiration: "",
			name: "",
			description: "",
			type: .credit
		)
	}
}

#if os(iOS)
@MainActor
final class CardScannerViewModelTests: XCTestCase {
	func testFailedUpdateStopsBeforeAlertAndIgnoresBufferedResult() async {
		await assertTerminalUpdateStops(.failed("The camera is unavailable."))
	}

	func testUnsupportedUpdateStopsBeforeAlertAndIgnoresBufferedResult() async {
		await assertTerminalUpdateStops(.unsupported("Card scanning is unavailable."))
	}

	func testRetryableFailureClearsCandidateAndContinuesScanning() async {
		let engine = TerminalUpdateCardScanningEngine(updates: [
			.candidate(lastFour: "1111", network: .visa),
			.retryableFailure("Could not confirm the card number. Try again."),
			.verified(CardScanResult(
				pan: "5555555555554444",
				expiry: nil,
				cardholderName: nil,
				network: .master
			))
		])
		let model = CardScannerViewModel(isRescan: false, engine: engine)
		var receivedResult = false

		await model.consumeUpdates(
			onPermissionDenied: { XCTFail("Unexpected permission callback") },
			onResult: { _, _ in receivedResult = true }
		)

		XCTAssertTrue(engine.didStop)
		XCTAssertFalse(model.showsMessage)
		XCTAssertNil(model.candidateLastFour)
		XCTAssertNil(model.candidateNetwork)
		XCTAssertTrue(receivedResult)
	}

	func testStopBeforeConsumingDoesNotStartTheEngineStream() async {
		let engine = StreamStartTrackingCardScanningEngine()
		let model = CardScannerViewModel(isRescan: false, engine: engine)
		model.stop()

		await model.consumeUpdates(
			onPermissionDenied: { XCTFail("Unexpected permission callback") },
			onResult: { _, _ in XCTFail("Unexpected scan result") }
		)

		XCTAssertTrue(engine.didStop)
		XCTAssertFalse(engine.didStartStream)
	}

	private func assertTerminalUpdateStops(_ terminalUpdate: CardScanUpdate) async {
		let engine = TerminalUpdateCardScanningEngine(updates: [
			terminalUpdate,
			.verified(CardScanResult(
				pan: "4111111111111111",
				expiry: "12/30",
				cardholderName: "JANE DOE",
				network: .visa
			))
		])
		let model = CardScannerViewModel(isRescan: false, engine: engine)
		var receivedResult = false

		await model.consumeUpdates(
			onPermissionDenied: { XCTFail("Unexpected permission callback") },
			onResult: { _, _ in receivedResult = true }
		)

		XCTAssertTrue(engine.didStop)
		XCTAssertTrue(model.showsMessage)
		XCTAssertFalse(receivedResult)
	}
}

@MainActor
private final class TerminalUpdateCardScanningEngine: CardScanningEngine {
	let engineID = "terminal-update-spy"
	private let updates: [CardScanUpdate]
	private(set) var didStop = false

	init(updates: [CardScanUpdate]) {
		self.updates = updates
	}

	func makeCameraView() -> AnyView { AnyView(EmptyView()) }

	func scanUpdates() -> AsyncStream<CardScanUpdate> {
		let streamUpdates = updates
		return AsyncStream { continuation in
			for update in streamUpdates {
				continuation.yield(update)
			}
			continuation.finish()
		}
	}

	func verifyCurrentCandidate() async -> CardScanResult? { nil }

	func stop() {
		didStop = true
	}
}

@MainActor
private final class StreamStartTrackingCardScanningEngine: CardScanningEngine {
	let engineID = "stream-start-tracker"
	private(set) var didStartStream = false
	private(set) var didStop = false

	func makeCameraView() -> AnyView { AnyView(EmptyView()) }

	func scanUpdates() -> AsyncStream<CardScanUpdate> {
		didStartStream = true
		return AsyncStream { $0.finish() }
	}

	func verifyCurrentCandidate() async -> CardScanResult? { nil }

	func stop() {
		didStop = true
	}
}
#endif

final class CardScanAnalyticsTests: XCTestCase {
	func testScanEventsNeverIncludeSensitiveCardFields() {
		let events: [AppAnalyticsEvent] = [
			.cardScanStarted(engine: "vision"),
			.cardScanPermissionDenied(engine: "vision"),
			.cardScanRescanRequested(engine: "vision"),
			.cardScanCompleted(
				engine: "vision",
				panSuccess: true,
				expirySuccess: true,
				holderSuccess: false,
				timeToPanMs: 420,
				timeToCompleteMs: 980,
				rescan: false
			)
		]

		let forbidden = [
			"pan", "number", "card_number", "cardholder", "holder", "name",
			"expiry", "expiration", "cvv", "ocr", "image", "transcript"
		]

		for event in events {
			let keys = Set(event.properties.keys.map { $0.lowercased() })
			for key in forbidden {
				XCTAssertFalse(keys.contains(key), "\(event.name) leaked \(key)")
			}
			for (key, value) in event.properties {
				XCTAssertFalse("\(value)".contains("4111"), "\(event.name).\(key) included a PAN")
			}
		}

		let completed = AppAnalyticsEvent.cardScanCompleted(
			engine: "vision",
			panSuccess: true,
			expirySuccess: false,
			holderSuccess: false,
			timeToPanMs: 420,
			timeToCompleteMs: 980,
			rescan: true
		)
		XCTAssertEqual(completed.properties["engine"], .string("vision"))
		XCTAssertEqual(completed.properties["pan_success"], .bool(true))
		XCTAssertEqual(completed.properties["time_to_pan_ms"], .int(420))
		XCTAssertEqual(completed.properties["rescan"], .bool(true))
	}
}
