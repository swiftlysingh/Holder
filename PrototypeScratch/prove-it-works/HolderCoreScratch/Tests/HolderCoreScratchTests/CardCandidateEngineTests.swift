import XCTest
@testable import HolderCoreScratch

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

	func testCardholderNameRejectsIssuerAndWebsiteText() {
		let rejected = [
			"www.hdfcbank.com",
			"HDFC BANK",
			"STATE BANK OF INDIA",
			"HDFCBANK COM",
			"CUSTOMER CARE",
			"ACME CARD SERVICES"
		]

		for text in rejected {
			XCTAssertNil(CardholderNameParser.normalizedName(text), text)
		}
	}

	func testCardholderNameKeepsPunctuationUsedInNames() {
		XCTAssertEqual(CardholderNameParser.normalizedName("ANNE-MARIE O'NEIL"), "ANNE-MARIE O'NEIL")
	}

	func testObservationPrefersANameOverBankBranding() {
		let observation = CardCandidateEngine.observe([
			OCRTextItem(text: "www . hdfc bank . com"),
			OCRTextItem(text: "STATE BANK OF INDIA"),
			OCRTextItem(text: "JANE DOE")
		])

		XCTAssertEqual(observation.cardholderName, "JANE DOE")
	}

	func testObservationReturnsNoNameForBrandingOnly() {
		let observation = CardCandidateEngine.observe([
			OCRTextItem(text: "www.hdfcbank.com"),
			OCRTextItem(text: "HDFC BANK")
		])

		XCTAssertNil(observation.cardholderName)
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
