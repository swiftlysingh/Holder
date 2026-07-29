#if os(macOS)
import XCTest
@testable import Holder

final class MenuBarSessionTests: XCTestCase {
	func testContentStateLocksBeforeCheckingForActiveCards() {
		XCTAssertEqual(
			MenuBarContentState(isAuthEnabled: true, isUnlocked: false, hasActiveCards: false),
			.locked
		)
		XCTAssertEqual(
			MenuBarContentState(isAuthEnabled: true, isUnlocked: false, hasActiveCards: true),
			.locked
		)
		XCTAssertEqual(
			MenuBarContentState(isAuthEnabled: false, isUnlocked: false, hasActiveCards: false),
			.empty
		)
		XCTAssertEqual(
			MenuBarContentState(isAuthEnabled: true, isUnlocked: true, hasActiveCards: false),
			.empty
		)
		XCTAssertEqual(
			MenuBarContentState(isAuthEnabled: false, isUnlocked: false, hasActiveCards: true),
			.cards
		)
		XCTAssertEqual(
			MenuBarContentState(isAuthEnabled: true, isUnlocked: true, hasActiveCards: true),
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
