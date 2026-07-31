import XCTest
@testable import Holder

@MainActor
final class CardViewModelTests: XCTestCase {
	func testStaleUserDefaultsAuthenticationDoesNotUnlockNewModel() {
		let previousValue = UserDefaults.standard.object(forKey: "auth")
		UserDefaults.standard.set(true, forKey: "auth")
		defer {
			if let previousValue {
				UserDefaults.standard.set(previousValue, forKey: "auth")
			} else {
				UserDefaults.standard.removeObject(forKey: "auth")
			}
		}

		XCTAssertFalse(makeModel().isAuthenticated)
	}

	func testSeparateModelsDoNotShareAuthenticationState() {
		let firstModel = makeModel()
		firstModel.isAuthenticated = true

		XCTAssertTrue(firstModel.isAuthenticated)
		XCTAssertFalse(makeModel().isAuthenticated)
	}

	func testAuthenticateUserUnlocksImmediatelyWhenAuthDisabled() {
		let previousValue = UserSettings.shared.isAuthEnabled
		UserSettings.shared.isAuthEnabled = false
		defer { UserSettings.shared.isAuthEnabled = previousValue }

		let model = makeModel()
		XCTAssertFalse(model.isAuthenticated)

		model.authenticateUser()

		XCTAssertTrue(model.isAuthenticated)
		XCTAssertFalse(model.isAuthenticating)
	}

	func testLockClearsAuthenticationImmediately() {
		let model = makeModel()
		model.isAuthenticated = true

		model.lock()

		XCTAssertFalse(model.isAuthenticated)
	}

	func testScheduledLockLocksAfterDelay() async throws {
		let sleeper = ControllableAsyncSleeper()
		let model = makeModel(sleeper: sleeper)
		model.isAuthenticated = true

		model.scheduleLock(after: .seconds(1))
		XCTAssertTrue(model.isAuthenticated)

		await sleeper.waitUntilSleeping(count: 1)
		await sleeper.advance()
		await waitUntil { !model.isAuthenticated }
		XCTAssertFalse(model.isAuthenticated)
	}

	func testScheduledLockCanBeCancelled() async throws {
		let sleeper = ControllableAsyncSleeper()
		let model = makeModel(sleeper: sleeper)
		model.isAuthenticated = true

		model.scheduleLock(after: .seconds(1))
		await sleeper.waitUntilSleeping(count: 1)
		model.cancelScheduledLock()
		await sleeper.advance()
		XCTAssertTrue(model.isAuthenticated)
	}

	func testBecomingActiveBeforeDeadlineCancelsLock() async {
		let sleeper = ControllableAsyncSleeper()
		let model = makeModel(sleeper: sleeper)
		model.isAuthenticated = true

		model.scheduleLock(after: .seconds(60))
		await sleeper.waitUntilSleeping(count: 1)
		model.resolveScheduledLockOnActive()
		await sleeper.advance()

		XCTAssertTrue(model.isAuthenticated)
	}

	func testBecomingActiveAfterDeadlineLocksImmediately() async {
		let sleeper = ControllableAsyncSleeper()
		let model = makeModel(sleeper: sleeper)
		model.isAuthenticated = true

		model.scheduleLock(after: .seconds(1))
		await sleeper.waitUntilSleeping(count: 1)
		model.resolveScheduledLockOnActive(
			at: ContinuousClock().now.advanced(by: .seconds(2))
		)

		XCTAssertFalse(model.isAuthenticated)
	}

	func testScheduledLockDoesNotRetainModel() async {
		let sleeper = ControllableAsyncSleeper()
		weak var weakModel: CardViewModel?

		do {
			var model: CardViewModel? = makeModel(sleeper: sleeper)
			weakModel = model
			model?.scheduleLock(after: .seconds(60))
			await sleeper.waitUntilSleeping(count: 1)
			model = nil
		}
		await Task.yield()

		XCTAssertNil(weakModel)
	}

	func testReschedulingReplacesPreviousLockTask() async throws {
		let sleeper = ControllableAsyncSleeper()
		let model = makeModel(sleeper: sleeper)
		model.isAuthenticated = true

		model.scheduleLock(after: .seconds(1))
		await sleeper.waitUntilSleeping(count: 1)
		model.scheduleLock(after: .seconds(2))
		// Cumulative count distinguishes the replacement from the cancelled first waiter.
		await sleeper.waitUntilSleeping(count: 2)

		XCTAssertTrue(model.isAuthenticated)
		await sleeper.advance()
		await waitUntil { !model.isAuthenticated }
		XCTAssertFalse(model.isAuthenticated)
	}

	func testLockCancelsPendingScheduledLock() async throws {
		let sleeper = ControllableAsyncSleeper()
		let model = makeModel(sleeper: sleeper)
		model.isAuthenticated = true

		model.scheduleLock(after: .seconds(1))
		await sleeper.waitUntilSleeping(count: 1)
		model.lock()
		XCTAssertFalse(model.isAuthenticated)

		// Simulate a later unlock; the cancelled schedule must not re-lock.
		model.isAuthenticated = true
		await sleeper.advance()
		XCTAssertTrue(model.isAuthenticated)
	}

	func testStaleAuthSuccessAfterLockDoesNotReUnlock() async {
		let previousValue = UserSettings.shared.isAuthEnabled
		UserSettings.shared.isAuthEnabled = true
		defer { UserSettings.shared.isAuthEnabled = previousValue }

		let authenticator = MockCardAuthenticator()
		let model = makeModel(authenticator: authenticator)

		model.authenticateUser()
		XCTAssertTrue(model.isAuthenticating)
		XCTAssertFalse(model.isAuthenticated)

		model.lock()
		XCTAssertFalse(model.isAuthenticated)
		XCTAssertFalse(model.isAuthenticating)
		XCTAssertEqual(authenticator.invalidateCount, 1)

		authenticator.completeOldest(success: true)
		await Task.yield()

		XCTAssertFalse(model.isAuthenticated)
	}

	func testStaleAuthSuccessAfterNewerAttemptDoesNotUnlock() async {
		let previousValue = UserSettings.shared.isAuthEnabled
		UserSettings.shared.isAuthEnabled = true
		defer { UserSettings.shared.isAuthEnabled = previousValue }

		let authenticator = MockCardAuthenticator()
		let model = makeModel(authenticator: authenticator)

		model.authenticateUser()
		model.authenticateUser()
		XCTAssertEqual(authenticator.evaluateCount, 2)
		XCTAssertEqual(authenticator.invalidateCount, 1)

		authenticator.completeOldest(success: true)
		await Task.yield()
		XCTAssertFalse(model.isAuthenticated, "First attempt success must be ignored")

		authenticator.completeOldest(success: true)
		await Task.yield()
		XCTAssertTrue(model.isAuthenticated)
		XCTAssertFalse(model.isAuthenticating)
	}

	func testAuthDisabledInvalidatesInFlightAttemptAndUnlocks() async {
		let previousValue = UserSettings.shared.isAuthEnabled
		UserSettings.shared.isAuthEnabled = true
		defer { UserSettings.shared.isAuthEnabled = previousValue }

		let authenticator = MockCardAuthenticator()
		let model = makeModel(authenticator: authenticator)

		model.authenticateUser()
		XCTAssertTrue(model.isAuthenticating)

		UserSettings.shared.isAuthEnabled = false
		model.authenticateUser()

		XCTAssertTrue(model.isAuthenticated)
		XCTAssertFalse(model.isAuthenticating)
		XCTAssertEqual(authenticator.invalidateCount, 1)

		authenticator.completeOldest(success: true)
		await Task.yield()
		XCTAssertTrue(model.isAuthenticated)
	}

	func testFailedAuthLeavesModelLocked() async {
		let previousValue = UserSettings.shared.isAuthEnabled
		UserSettings.shared.isAuthEnabled = true
		defer { UserSettings.shared.isAuthEnabled = previousValue }

		let authenticator = MockCardAuthenticator()
		let model = makeModel(authenticator: authenticator)

		model.authenticateUser()
		authenticator.completeOldest(success: false)
		await Task.yield()

		XCTAssertFalse(model.isAuthenticated)
		XCTAssertFalse(model.isAuthenticating)
	}

	private func makeModel(
		authenticator: MockCardAuthenticator? = nil,
		sleeper: AsyncSleeper = TaskAsyncSleeper()
	) -> CardViewModel {
		CardViewModel(
			card: CardData(
				id: UUID(),
				number: "4111111111111111",
				cvv: "123",
				expiration: "12/30",
				name: "Test Card",
				description: "",
				type: .creditCard
			),
			addUpdateCard: { _ in },
			authenticatorFactory: MockCardAuthenticatorFactory(authenticator ?? MockCardAuthenticator()),
			sleeper: sleeper
		)
	}

	/// Bounded poll so assertions wait for main-actor lock work after an injected sleeper advances,
	/// without depending on a single `Task.yield` ordering.
	private func waitUntil(
		timeout: Duration = .seconds(1),
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

// MARK: - Test doubles

@MainActor
final class MockCardAuthenticator: CardAuthenticating {
	var canEvaluate = true
	private(set) var evaluateCount = 0
	private(set) var invalidateCount = 0
	private var pendingReplies: [(Bool) -> Void] = []

	func canEvaluateDeviceOwnerAuthentication() -> Bool { canEvaluate }

	func evaluateDeviceOwnerAuthentication(reason: String, reply: @escaping (Bool) -> Void) {
		evaluateCount += 1
		pendingReplies.append(reply)
	}

	func invalidate() {
		invalidateCount += 1
	}

	func completeOldest(success: Bool) {
		guard !pendingReplies.isEmpty else {
			XCTFail("No pending authentication replies")
			return
		}
		let reply = pendingReplies.removeFirst()
		reply(success)
	}
}

struct MockCardAuthenticatorFactory: CardAuthenticatorFactory {
	let authenticator: CardAuthenticating

	init(_ authenticator: CardAuthenticating) {
		self.authenticator = authenticator
	}

	func makeAuthenticator() -> CardAuthenticating {
		authenticator
	}
}

/// Advances waiters explicitly so lock-scheduling tests avoid real sleeps.
///
/// Waiter registration is cumulative so tests can barrier on a specific sleep
/// generation (e.g. the replacement after a reschedule) without mistaking a
/// cancelled predecessor for the active waiter.
actor ControllableAsyncSleeper: AsyncSleeper {
	private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]
	private var waiterOrder: [UUID] = []
	private var cancelledBeforeRegister: Set<UUID> = []
	private var cumulativeRegisteredCount = 0
	private var sleepingBarriers: [(requiredCount: Int, continuation: CheckedContinuation<Void, Never>)] = []

	func sleep(for duration: Duration) async throws {
		let id = UUID()
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
				Task { await self.registerWaiter(id: id, continuation: continuation) }
			}
		} onCancel: {
			Task { await self.cancelWaiter(id: id) }
		}
	}

	/// Suspends until at least `count` sleep waiters have been registered (cumulative).
	func waitUntilSleeping(count: Int = 1) async {
		precondition(count > 0)
		if cumulativeRegisteredCount >= count {
			return
		}
		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			sleepingBarriers.append((requiredCount: count, continuation: continuation))
		}
	}

	func advance() async {
		guard let id = waiterOrder.first else {
			return
		}
		finish(id: id, with: .success(()))
		await Task.yield()
	}

	private func registerWaiter(id: UUID, continuation: CheckedContinuation<Void, Error>) {
		if cancelledBeforeRegister.remove(id) != nil {
			continuation.resume(throwing: CancellationError())
			return
		}
		waiters[id] = continuation
		waiterOrder.append(id)
		cumulativeRegisteredCount += 1
		resumeSleepingBarriersIfNeeded()
	}

	private func cancelWaiter(id: UUID) {
		if waiters[id] != nil {
			finish(id: id, with: .failure(CancellationError()))
		} else {
			cancelledBeforeRegister.insert(id)
		}
	}

	private func resumeSleepingBarriersIfNeeded() {
		var remaining: [(requiredCount: Int, continuation: CheckedContinuation<Void, Never>)] = []
		for barrier in sleepingBarriers {
			if cumulativeRegisteredCount >= barrier.requiredCount {
				barrier.continuation.resume()
			} else {
				remaining.append(barrier)
			}
		}
		sleepingBarriers = remaining
	}

	private func finish(id: UUID, with result: Result<Void, Error>) {
		guard let continuation = waiters.removeValue(forKey: id) else {
			return
		}
		waiterOrder.removeAll { $0 == id }

		switch result {
		case .success:
			continuation.resume()
		case .failure(let error):
			continuation.resume(throwing: error)
		}
	}
}
