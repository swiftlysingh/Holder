import CoreGraphics
import XCTest
@testable import Holder

#if os(iOS)
import SwiftUI
#endif

final class CardCandidateEngineTests: XCTestCase {
	func testReconstructsSplitVisaPAN() {
		let items = [
			OCRTextItem(text: "4111"),
			OCRTextItem(text: "1111"),
			OCRTextItem(text: "1111"),
			OCRTextItem(text: "1111")
		]

		XCTAssertEqual(CardCandidateEngine.reconstructPANs(from: items), ["4111111111111111"])
	}

	func testReconstructsMultilineAmexPAN() {
		let items = [
			OCRTextItem(text: "3782"),
			OCRTextItem(text: "822463"),
			OCRTextItem(text: "10005")
		]

		XCTAssertEqual(CardCandidateEngine.reconstructPANs(from: items), ["378282246310005"])
	}

	func testNormalizesSafeOCRConfusionBeforeLuhn() {
		let items = [OCRTextItem(text: "4111 1111 111l 1111")]
		XCTAssertEqual(CardCandidateEngine.reconstructPANs(from: items), ["4111111111111111"])
	}

	func testDoesNotCombineAlternativeCandidatesAcrossItems() {
		let items = [
			OCRTextItem(text: "4111", candidates: ["4111", "0000"]),
			OCRTextItem(text: "1111", candidates: ["1111", "2222"])
		]

		XCTAssertEqual(CardCandidateEngine.reconstructPANs(from: items), [])
	}

	func testRejectsInvalidLuhnEvenWhenLengthMatches() {
		let items = [OCRTextItem(text: "4111111111111112")]
		XCTAssertEqual(CardCandidateEngine.reconstructPANs(from: items), [])
	}

	func testRejectsLuhnValidUnknownIIN() {
		let items = [OCRTextItem(text: "0000000000000000")]
		XCTAssertEqual(CardCandidateEngine.reconstructPANs(from: items), [])
	}

	func testReconstructsVerticalCardPANFromBoundingBoxes() {
		let items = [
			OCRTextItem(text: "4111", boundingBox: CGRect(x: 0.20, y: 0.72, width: 0.12, height: 0.08)),
			OCRTextItem(text: "1111", boundingBox: CGRect(x: 0.21, y: 0.58, width: 0.12, height: 0.08)),
			OCRTextItem(text: "1111", boundingBox: CGRect(x: 0.19, y: 0.44, width: 0.12, height: 0.08)),
			OCRTextItem(text: "1111", boundingBox: CGRect(x: 0.20, y: 0.30, width: 0.12, height: 0.08))
		]

		XCTAssertEqual(CardCandidateEngine.reconstructPANs(from: items), ["4111111111111111"])
	}

	func testInfersNetworksFromIIN() {
		XCTAssertEqual(CardPAN.network(for: "4111111111111111"), .visa)
		XCTAssertEqual(CardPAN.network(for: "5555555555554444"), .master)
		XCTAssertEqual(CardPAN.network(for: "378282246310005"), .amex)
		XCTAssertEqual(CardPAN.network(for: "6011111111111117"), .discover)
		XCTAssertEqual(CardPAN.network(for: "3530111333300000"), .jcb)
		XCTAssertEqual(CardPAN.network(for: "30569309025904"), .diners)
		XCTAssertEqual(CardPAN.network(for: "6200000000000005"), .unionPay)
		XCTAssertEqual(CardPAN.network(for: "6000000000000007"), .rupay)
		XCTAssertEqual(CardPAN.network(for: "8100000000000002"), .rupay)
	}

	func testFormatsAmexAndGroupedPANs() {
		XCTAssertEqual(CardPAN.formatted("378282246310005"), "3782 822463 10005")
		XCTAssertEqual(CardPAN.formatted("4111111111111111"), "4111 1111 1111 1111")
	}

	func testExpiryParsingAcceptsCommonFormatsAndRejectsBadDates() {
		let now = date(year: 2026, month: 8, day: 18)
		XCTAssertEqual(CardExpiryParser.parse("12/30", now: now), "12/30")
		XCTAssertEqual(CardExpiryParser.parse("GOOD THRU 12/2030", now: now), "12/30")
		XCTAssertEqual(CardExpiryParser.parse("1227", now: now), "12/27")
		XCTAssertNil(CardExpiryParser.parse("13/27", now: now))
		XCTAssertNil(CardExpiryParser.parse("01/40", now: now))
		XCTAssertNil(CardExpiryParser.parse("01/25", now: now))
	}

	func testCardholderNameIgnoresNetworkLabels() {
		let items = [
			OCRTextItem(text: "VISA"),
			OCRTextItem(text: "4111 1111 1111 1111"),
			OCRTextItem(text: "JOHN DOE"),
			OCRTextItem(text: "VALID THRU 12/30")
		]
		XCTAssertEqual(CardholderNameParser.parse(from: items, panDigits: "4111111111111111"), "JOHN DOE")
		XCTAssertNil(CardholderNameParser.normalizedName("VISA"))
	}

	func testCardholderNamePrefersLowerVisionText() {
		let items = [
			OCRTextItem(text: "ACME FINANCIAL", boundingBox: CGRect(x: 0.1, y: 0.72, width: 0.4, height: 0.06)),
			OCRTextItem(text: "JANE DOE", boundingBox: CGRect(x: 0.1, y: 0.14, width: 0.3, height: 0.06))
		]

		XCTAssertEqual(CardholderNameParser.parse(from: items, panDigits: nil), "JANE DOE")
	}

	func testTemporalVotingRequiresRepeatedPAN() {
		var voter = TemporalPANVoter(windowSize: 8, requiredVotes: 2)
		XCTAssertNil(voter.record("4111111111111111"))
		XCTAssertEqual(voter.record("4111111111111111"), "4111111111111111")
	}

	func testTemporalVotingIgnoresTiedPANs() {
		var voter = TemporalPANVoter(windowSize: 8, requiredVotes: 2)
		XCTAssertNil(voter.record("4111111111111111"))
		XCTAssertNil(voter.record("5555555555554444"))
		XCTAssertEqual(voter.record("4111111111111111"), "4111111111111111")
		XCTAssertNil(voter.record("5555555555554444"))
	}

	private func date(year: Int, month: Int, day: Int) -> Date {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		return Calendar(identifier: .gregorian).date(from: components)!
	}
}

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
				type: .creditCard
			),
			isEditing: true,
			addNewFlow: true,
			addUpdateCard: { _ in true }
		)

		model.applyScan(
			CardScanResult(pan: "378282246310005", expiry: nil, cardholderName: nil, network: .amex)
		)

		XCTAssertEqual(model.card.number, "3782 822463 10005")
		XCTAssertEqual(model.card.network, .amex)
		XCTAssertEqual(model.card.expiration, "08/29")
		XCTAssertEqual(model.card.name, "KEPT NAME")
		XCTAssertEqual(model.card.cvv, "999")
		XCTAssertEqual(model.card.description, "Wallet")
		XCTAssertTrue(model.didUseScanner)
		XCTAssertFalse(model.isShowingScanner)
	}

	private func makeBlankCard() -> CardData {
		CardData(
			id: UUID(),
			number: "",
			cvv: "",
			expiration: "",
			name: "",
			description: "",
			type: .creditCard
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
