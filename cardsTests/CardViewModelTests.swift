import Combine
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

	func testScannerResultRequiresCurrentAuthenticatedAddSession() {
		let model = makeModel(isEditing: true, addNewFlow: true)
		model.isAuthenticated = true
		let generation = model.authenticationGeneration

		XCTAssertTrue(model.applyScannerResult(
			number: "5555444433331111",
			holder: "Scanned holder",
			expiration: "10/31",
			authenticationGeneration: generation
		))
		XCTAssertEqual(model.card.number, "5555444433331111")
		XCTAssertEqual(model.card.name, "Scanned holder")
		XCTAssertEqual(model.card.expiration, "10/31")
		XCTAssertTrue(model.didUseScanner)
	}

	func testScannerResultAfterLockCannotRepopulateDraft() {
		let model = makeModel(isEditing: true, addNewFlow: true)
		model.isAuthenticated = true
		let staleGeneration = model.authenticationGeneration
		let originalCard = model.card

		model.lock()

		XCTAssertFalse(model.applyScannerResult(
			number: "5555444433331111",
			holder: "Late result",
			expiration: "10/31",
			authenticationGeneration: staleGeneration
		))
		XCTAssertEqual(model.card, originalCard)
		XCTAssertFalse(model.didUseScanner)
	}

	func testScheduledLockLocksAfterDelay() async throws {
		let sleeper = ControllableAsyncSleeper()
		let model = makeModel(sleeper: sleeper)
		model.isAuthenticated = true

		model.scheduleLock(after: .seconds(1))
		XCTAssertTrue(model.isAuthenticated)

		await sleeper.waitUntilSleeping(count: 1)
		await sleeper.advance()
		await waitUntilLocked(model)
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
		let replacementDuration = await sleeper.requestedDuration(at: 1)
		XCTAssertEqual(replacementDuration, .seconds(2))

		XCTAssertTrue(model.isAuthenticated)
		await sleeper.advance()
		await waitUntilLocked(model)
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

	func testRevealRequiresAuthentication() async {
		let model = makeModel()

		model.reveal(.number, for: .zero)
		await Task.yield()

		XCTAssertFalse(model.isRevealed(.number))
		XCTAssertNil(model.copiedField)
	}

	func testDefaultRevealUsesFiniteDisclosureWindow() async {
		let model = makeModel()
		model.isAuthenticated = true

		// Calling without an override exercises the production 12-second default.
		model.reveal(.number)
		await Task.yield()

		XCTAssertTrue(model.isRevealed(.number))
		model.lock()
	}

	func testRevealClearsAfterInjectedShortTimeout() async {
		let model = makeModel()
		model.isAuthenticated = true

		model.reveal(.expiration, for: .zero)
		XCTAssertTrue(model.isRevealed(.expiration))

		for _ in 0..<8 {
			await Task.yield()
			if !model.isRevealed(.expiration) { break }
		}

		XCTAssertFalse(model.isRevealed(.expiration))
	}

	func testLockAndBackgroundClearTemporaryDisclosure() {
		let model = makeModel()
		model.isAuthenticated = true

		model.reveal(.number)
		XCTAssertTrue(model.isRevealed(.number))

		model.hideSensitiveValues()
		XCTAssertFalse(model.isRevealed(.number))

		model.reveal(.securityCode)
		XCTAssertTrue(model.isRevealed(.securityCode))
		model.copyAction(with: model.card.cvv, field: .securityCode)
		XCTAssertEqual(model.copiedField, .securityCode)
		model.lock()

		XCTAssertFalse(model.isAuthenticated)
		XCTAssertFalse(model.isRevealed(.securityCode))
		XCTAssertNil(model.copiedField)
	}

	func testCopyIsGatedUntilTheRequestedFieldIsRevealed() {
		let model = makeModel()
		model.isAuthenticated = true

		model.copyAction(with: model.card.number, field: .number)
		XCTAssertNil(model.copiedField)

		model.reveal(.number)
		model.copyAction(with: model.card.number, field: .number)
		XCTAssertEqual(model.copiedField, .number)
	}

	func testCardholderCopyUsesTheSameFiniteRevealGate() {
		let model = makeModel()
		model.isAuthenticated = true

		model.copyAction(with: model.card.name, field: .holderName)
		XCTAssertNil(model.copiedField)

		model.reveal(.holderName)
		model.copyAction(with: model.card.name, field: .holderName)
		XCTAssertEqual(model.copiedField, .holderName)
	}

	func testLockDiscardsPlaintextLegacyImageAndRejectsStalePickerCompletion() throws {
		let model = makeModel()
		model.card.type = .otherCard
		model.isAuthenticated = true
		let image = try XCTUnwrap(PlatformImage(data: Self.onePixelPNG))
		let staleGeneration = model.authenticationGeneration

		XCTAssertTrue(model.stageLegacyImage(
			image,
			authenticationGeneration: staleGeneration
		))
		XCTAssertNotNil(model.cardImage)

		model.lock()
		XCTAssertNil(model.cardImage)

		model.isAuthenticated = true
		XCTAssertFalse(model.stageLegacyImage(
			image,
			authenticationGeneration: staleGeneration
		))
		XCTAssertNil(model.cardImage)
	}

	func testLegacyImageMutationRequiresDurableMarkerAndCleansAppliedReplacement() throws {
		let cardID = UUID()
		var savedCards: [CardData] = []
		var imageSaveIDs: [UUID] = []
		var deletedIDs: [UUID] = []
		let model = CardViewModel(
			card: CardData(
				id: cardID,
				number: "",
				cvv: "",
				expiration: "",
				name: "",
				description: "Legacy card",
				type: .otherCard,
				hasLegacyImage: nil
			),
			addUpdateCard: {
				savedCards.append($0)
				return true
			},
			loadLegacyImage: { _ in nil },
			saveLegacyImage: { _, id in
				imageSaveIDs.append(id)
				return true
			},
			deleteLegacyImage: {
				deletedIDs.append($0)
				return true
			}
		)
		model.isAuthenticated = true
		let image = try XCTUnwrap(PlatformImage(data: Self.onePixelPNG))

		XCTAssertTrue(model.stageLegacyImage(
			image,
			authenticationGeneration: model.authenticationGeneration
		))
		XCTAssertFalse(model.applyLegacyImageChangesForSave())
		XCTAssertTrue(imageSaveIDs.isEmpty)

		XCTAssertTrue(model.persistLegacyImageMutationMarkerForSave())
		XCTAssertEqual(savedCards.count, 1)
		XCTAssertEqual(savedCards.last?.hasLegacyImage, true)
		XCTAssertTrue(model.applyLegacyImageChangesForSave())
		XCTAssertEqual(imageSaveIDs, [cardID])
		XCTAssertTrue(model.hasUnresolvedLegacyImageMutation)

		model.card.type = .creditCard
		model.stageLegacyImageRemovalIfNoLongerNeeded()
		XCTAssertTrue(model.applyLegacyImageChangesForSave())

		XCTAssertEqual(deletedIDs, [cardID])
		XCTAssertEqual(model.card.hasLegacyImage, false)
		XCTAssertTrue(model.addUpdateCard(model.card))
		model.finalizeLegacyImageChangesAfterSave()
		XCTAssertFalse(model.hasUnresolvedLegacyImageMutation)
		XCTAssertEqual(savedCards.last?.hasLegacyImage, false)
	}

	func testFailedLegacyImageMarkerWriteNeverTouchesICloud() throws {
		var remoteSaveCount = 0
		let model = CardViewModel(
			card: CardData(
				id: UUID(),
				number: "",
				cvv: "",
				expiration: "",
				name: "",
				description: "Legacy card",
				type: .otherCard,
				hasLegacyImage: false
			),
			addUpdateCard: { _ in false },
			loadLegacyImage: { _ in nil },
			saveLegacyImage: { _, _ in
				remoteSaveCount += 1
				return true
			}
		)
		model.isAuthenticated = true
		let image = try XCTUnwrap(PlatformImage(data: Self.onePixelPNG))

		XCTAssertTrue(model.stageLegacyImage(
			image,
			authenticationGeneration: model.authenticationGeneration
		))
		XCTAssertFalse(model.persistLegacyImageMutationMarkerForSave())
		XCTAssertFalse(model.applyLegacyImageChangesForSave())
		XCTAssertEqual(remoteSaveCount, 0)
		XCTAssertFalse(model.hasUnresolvedLegacyImageMutation)
	}

	func testAppliedReplacementRestoresPresenceWhenTypeReturnsToOtherAfterDeleteFailure() throws {
		let model = CardViewModel(
			card: CardData(
				id: UUID(),
				number: "",
				cvv: "",
				expiration: "",
				name: "",
				description: "Legacy card",
				type: .otherCard,
				hasLegacyImage: false
			),
			addUpdateCard: { _ in true },
			loadLegacyImage: { _ in nil },
			saveLegacyImage: { _, _ in true },
			deleteLegacyImage: { _ in false }
		)
		model.isAuthenticated = true
		let image = try XCTUnwrap(PlatformImage(data: Self.onePixelPNG))

		XCTAssertTrue(model.stageLegacyImage(
			image,
			authenticationGeneration: model.authenticationGeneration
		))
		XCTAssertTrue(model.persistLegacyImageMutationMarkerForSave())
		XCTAssertTrue(model.applyLegacyImageChangesForSave())

		model.card.type = .creditCard
		model.stageLegacyImageRemovalIfNoLongerNeeded()
		XCTAssertFalse(model.applyLegacyImageChangesForSave())
		XCTAssertEqual(model.card.hasLegacyImage, false)

		model.card.type = .otherCard
		XCTAssertTrue(model.applyLegacyImageChangesForSave())
		XCTAssertEqual(model.card.hasLegacyImage, true)
	}

	func testLockFallsBackToPersistedCleanupMarkerWithoutKeepingPlaintext() throws {
		var savedMarker: CardData?
		let model = CardViewModel(
			card: CardData(
				id: UUID(),
				number: "",
				cvv: "",
				expiration: "",
				name: "",
				description: "Legacy card",
				type: .otherCard,
				hasLegacyImage: false
			),
			addUpdateCard: {
				savedMarker = $0
				return true
			},
			loadLegacyImage: { _ in nil },
			saveLegacyImage: { _, _ in true }
		)
		model.isAuthenticated = true
		let image = try XCTUnwrap(PlatformImage(data: Self.onePixelPNG))

		XCTAssertTrue(model.stageLegacyImage(
			image,
			authenticationGeneration: model.authenticationGeneration
		))
		XCTAssertTrue(model.persistLegacyImageMutationMarkerForSave())
		XCTAssertTrue(model.applyLegacyImageChangesForSave())

		model.lock()

		XCTAssertNil(model.cardImage)
		XCTAssertEqual(model.card, try XCTUnwrap(savedMarker))
		XCTAssertEqual(model.card.hasLegacyImage, true)
		XCTAssertFalse(model.hasUnresolvedLegacyImageMutation)
	}

	private func makeModel(
		authenticator: MockCardAuthenticator? = nil,
		sleeper: AsyncSleeper = TaskAsyncSleeper(),
		isEditing: Bool = false,
		addNewFlow: Bool = false
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
			isEditing: isEditing,
			addNewFlow: addNewFlow,
			addUpdateCard: { _ in true },
			authenticatorFactory: MockCardAuthenticatorFactory(authenticator ?? MockCardAuthenticator()),
			sleeper: sleeper
		)
	}

	private func waitUntilLocked(_ model: CardViewModel) async {
		for await isAuthenticated in model.$isAuthenticated.values {
			if !isAuthenticated { return }
		}
	}

	private static let onePixelPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
}

// MARK: - Test doubles

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
	private var requestedDurations: [Duration] = []
	private var cancelledBeforeRegister: Set<UUID> = []
	private var cumulativeRegisteredCount = 0
	private var sleepingBarriers: [(requiredCount: Int, continuation: CheckedContinuation<Void, Never>)] = []

	func sleep(for duration: Duration) async throws {
		let id = UUID()
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
				registerWaiter(id: id, duration: duration, continuation: continuation)
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

	func requestedDuration(at index: Int) -> Duration? {
		requestedDurations.indices.contains(index) ? requestedDurations[index] : nil
	}

	private func registerWaiter(
		id: UUID,
		duration: Duration,
		continuation: CheckedContinuation<Void, Error>
	) {
		if cancelledBeforeRegister.remove(id) != nil {
			continuation.resume(throwing: CancellationError())
			return
		}
		waiters[id] = continuation
		waiterOrder.append(id)
		requestedDurations.append(duration)
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
