import Foundation
import XCTest
@testable import Holder

final class PrivacyFormattingTests: XCTestCase {
	func testSecureCardAlwaysLimitsHomeDisplayToLastFourDigits() {
		XCTAssertEqual("4111 1111 1111 1234".toSecureCard(), "•••• 1234")
		XCTAssertEqual("378282246310005".toSecureCard(), "•••• 0005")
	}

	func testSecureCardHandlesEmptyAndShortValuesWithoutRevealingMore() {
		XCTAssertEqual("".toSecureCard(), "••••")
		XCTAssertEqual("123".toSecureCard(), "••••")
		XCTAssertEqual("1234".toSecureCard(), "••••")
		XCTAssertEqual("12345".toSecureCard(), "•••• 2345")
	}

	func testWidgetTailOmitsIdentifiersThatWouldBeRevealedInFull() {
		var card = CardData(
			id: UUID(),
			number: "123",
			cvv: "",
			expiration: "",
			name: "",
			description: "Transit pass",
			type: .travelCard
		)

		XCTAssertEqual(CardDataStore.widgetLastFourDigits(for: card), "")
		card.number = "1234"
		XCTAssertEqual(CardDataStore.widgetLastFourDigits(for: card), "")
		card.number = "12345"
		XCTAssertEqual(CardDataStore.widgetLastFourDigits(for: card), "2345")
	}

	func testWidgetDisplayNameNeverFallsBackToCardholderName() {
		let card = CardData(
			id: UUID(),
			number: "4111111111111234",
			cvv: "123",
			expiration: "12/30",
			name: "Private Cardholder",
			description: "",
			type: .creditCard
		)

		XCTAssertEqual(CardDataStore.widgetDisplayName(for: card), "Credit Card")
		XCTAssertEqual(card.displayLabel, "Credit Card")
	}

	func testWidgetDisplayNameUsesExplicitTrimmedCardLabel() {
		var card = CardData(
			id: UUID(),
			number: "4111111111111234",
			cvv: "123",
			expiration: "12/30",
			name: "Private Cardholder",
			description: "  Daily Visa  ",
			type: .creditCard
		)

		XCTAssertEqual(CardDataStore.widgetDisplayName(for: card), "Daily Visa")
		card.description = "   "
		XCTAssertEqual(CardDataStore.widgetDisplayName(for: card), "Credit Card")
	}
}
