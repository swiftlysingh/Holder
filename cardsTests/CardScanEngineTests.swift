import CoreGraphics
import XCTest
@testable import Holder

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

	func testTemporalVotingRequiresRepeatedPAN() {
		var voter = TemporalPANVoter(windowSize: 8, requiredVotes: 2)
		XCTAssertNil(voter.record("4111111111111111"))
		XCTAssertEqual(voter.record("4111111111111111"), "4111111111111111")
	}

	func testTemporalVotingIgnoresTiedPANs() {
		var voter = TemporalPANVoter(windowSize: 8, requiredVotes: 2)
		XCTAssertNil(voter.record("4111111111111111"))
		XCTAssertNil(voter.record("5555555555554444"))
		XCTAssertNil(voter.record("4111111111111111"))
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
			CardScanResult(pan: "378282246310005", expiry: nil, cardholderName: nil, network: .amex),
			wasRescan: true
		)

		XCTAssertEqual(model.card.number, "3782 822463 10005")
		XCTAssertEqual(model.card.network, .amex)
		XCTAssertEqual(model.card.expiration, "08/29")
		XCTAssertEqual(model.card.name, "KEPT NAME")
		XCTAssertEqual(model.card.cvv, "999")
		XCTAssertEqual(model.card.description, "Wallet")
		XCTAssertTrue(model.didUseScanner)
		XCTAssertTrue(model.lastScanWasRescan)
		XCTAssertEqual(model.entryMode, .form)
		XCTAssertFalse(model.isShowingScanner)
	}

	func testAddNewPaymentCardStartsOnChooser() {
		let model = CardViewModel(
			card: CardData(
				id: UUID(),
				number: "",
				cvv: "",
				expiration: "",
				name: "",
				description: "",
				type: .creditCard
			),
			isEditing: true,
			addNewFlow: true,
			addUpdateCard: { _ in true }
		)
		XCTAssertEqual(model.entryMode, .chooser)
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
		XCTAssertEqual(completed.properties["pan_success"], .string("true"))
		XCTAssertEqual(completed.properties["time_to_pan_ms"], .string("420"))
		XCTAssertEqual(completed.properties["rescan"], .string("true"))
	}
}
