#if os(macOS)
import XCTest
@testable import Holder

final class MenuBarSessionTests: XCTestCase {
	func testContentStateLocksBeforeCheckingCardsOrLoadStatus() {
		XCTAssertEqual(
			MenuBarContentState(
				isAuthEnabled: true,
				isUnlocked: false,
				hasActiveCards: false,
				didLoadFail: true
			),
			.locked
		)
		XCTAssertEqual(
			MenuBarContentState(
				isAuthEnabled: true,
				isUnlocked: false,
				hasActiveCards: true,
				didLoadFail: false
			),
			.locked
		)
	}

	func testContentStateShowsCardsWithoutAuthentication() {
		XCTAssertEqual(
			MenuBarContentState(
				isAuthEnabled: false,
				isUnlocked: false,
				hasActiveCards: true,
				didLoadFail: false
			),
			.cards
		)
	}

	func testContentStateDistinguishesEmptyFromUnavailable() {
		XCTAssertEqual(
			MenuBarContentState(
				isAuthEnabled: false,
				isUnlocked: false,
				hasActiveCards: false,
				didLoadFail: false
			),
			.empty
		)
		XCTAssertEqual(
			MenuBarContentState(
				isAuthEnabled: false,
				isUnlocked: false,
				hasActiveCards: false,
				didLoadFail: true
			),
			.unavailable
		)
	}

	func testContentStateKeepsCachedCardsVisibleAfterFailedRefresh() {
		XCTAssertEqual(
			MenuBarContentState(
				isAuthEnabled: false,
				isUnlocked: false,
				hasActiveCards: true,
				didLoadFail: true
			),
			.cards
		)
	}

	@MainActor
	func testSessionLocksAtTimeoutAndCanBeCancelledImmediately() async throws {
		let session = MenuBarSession()

		session.unlock(for: .milliseconds(40))
		XCTAssertTrue(session.isUnlocked)
		try await Task.sleep(for: .milliseconds(250))
		XCTAssertFalse(session.isUnlocked)

		session.unlock(for: .seconds(60))
		XCTAssertTrue(session.isUnlocked)
		session.lock()
		XCTAssertFalse(session.isUnlocked)
	}

	@MainActor
	func testReplacementUnlockCancelsPriorTimeoutDeadline() async throws {
		let session = MenuBarSession()

		// Schedule a short timeout, then replace it with a long one. The first
		// deadline must not lock once superseded.
		session.unlock(for: .milliseconds(40))
		session.unlock(for: .milliseconds(500))
		XCTAssertTrue(session.isUnlocked)
		try await Task.sleep(for: .milliseconds(250))
		XCTAssertTrue(session.isUnlocked)

		session.lock()
		XCTAssertFalse(session.isUnlocked)
	}
}
#endif
