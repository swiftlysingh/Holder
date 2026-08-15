#if os(macOS)
import XCTest
@testable import Holder

final class MenuBarContentStateTests: XCTestCase {
	func testContentStateShowsCardsBeforeLoadFailure() {
		XCTAssertEqual(
			MenuBarContentState(
				hasActiveCards: true,
				didLoadFail: true
			),
			.cards
		)
	}

	func testContentStateShowsCards() {
		XCTAssertEqual(
			MenuBarContentState(
				hasActiveCards: true,
				didLoadFail: false
			),
			.cards
		)
	}

	func testContentStateDistinguishesEmptyFromUnavailable() {
		XCTAssertEqual(
			MenuBarContentState(
				hasActiveCards: false,
				didLoadFail: false
			),
			.empty
		)
		XCTAssertEqual(
			MenuBarContentState(
				hasActiveCards: false,
				didLoadFail: true
			),
			.unavailable
		)
	}

	func testContentStateKeepsCachedCardsVisibleAfterFailedRefresh() {
		XCTAssertEqual(
			MenuBarContentState(
				hasActiveCards: true,
				didLoadFail: true
			),
			.cards
		)
	}

}
#endif
