import XCTest
@testable import Holder

final class CardDataPrivacyTests: XCTestCase {
    func testFixedCardMaskShowsOnlyLastFourDigits() {
        XCTAssertEqual("4111 1111 1111 1234".maskedCardNumber(), "•••• 1234")
        XCTAssertEqual("4111-1111-1111-5678".maskedCardNumber(), "•••• 5678")
        XCTAssertEqual("123".maskedCardNumber(), "•••• 123")
        XCTAssertEqual("".maskedCardNumber(), "No number")
    }

    func testShareTextOmitsSecurityCodeUnlessExplicitlyIncluded() {
        let card = CardData(
            id: UUID(),
            number: "4111111111111111",
            cvv: "987",
            expiration: "12/30",
            name: "Test Card",
            description: "",
            type: .credit
        )

        let standardShare = card.toShareString(includeSecurityCode: false)
        XCTAssertTrue(standardShare.contains(card.number))
        XCTAssertTrue(standardShare.contains(card.expiration))
        XCTAssertFalse(standardShare.contains(card.cvv))

        XCTAssertTrue(
            card.toShareString(includeSecurityCode: true)
                .contains("Security Code: \(card.cvv)")
        )
    }
}
