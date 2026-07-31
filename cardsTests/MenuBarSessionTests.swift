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
		let sleeper = ControllableAsyncSleeper()
		let session = MenuBarSession(sleeper: sleeper)

		session.unlock(for: .seconds(60))
		XCTAssertTrue(session.isUnlocked)

		await sleeper.waitUntilSleeping(count: 1)
		await sleeper.advance()
		await waitUntil(timeout: .seconds(1)) { !session.isUnlocked }
		XCTAssertFalse(session.isUnlocked)

		session.unlock(for: .seconds(60))
		XCTAssertTrue(session.isUnlocked)
		session.lock()
		XCTAssertFalse(session.isUnlocked)
	}

	@MainActor
	func testReplacementUnlockCancelsPriorTimeoutDeadline() async throws {
		let sleeper = ControllableAsyncSleeper()
		let session = MenuBarSession(sleeper: sleeper)

		// Schedule a timeout, then replace it. Wait for the second cumulative
		// registration before completing the active waiter so the first cannot lock.
		session.unlock(for: .seconds(1))
		await sleeper.waitUntilSleeping(count: 1)
		session.unlock(for: .seconds(2))
		await sleeper.waitUntilSleeping(count: 2)
		XCTAssertTrue(session.isUnlocked)

		await sleeper.advance()
		await waitUntil(timeout: .seconds(1)) { !session.isUnlocked }
		XCTAssertFalse(session.isUnlocked)

		session.lock()
		XCTAssertFalse(session.isUnlocked)
	}

	@MainActor
	private func waitUntil(
		timeout: Duration,
		pollInterval: Duration = .milliseconds(5),
		condition: @MainActor () -> Bool
	) async {
		let deadline = ContinuousClock().now.advanced(by: timeout)
		while ContinuousClock().now < deadline {
			if condition() { return }
			try? await Task.sleep(for: pollInterval)
		}
	}
}
#endif
