import Combine
import XCTest
@testable import Holder

@MainActor
final class AuthenticationSessionTests: XCTestCase {
    func testInitialStateIsFailClosed() {
        let session = makeSession()

        XCTAssertFalse(session.isVaultUnlocked)
        XCTAssertFalse(session.isSensitiveAccessFresh)
        XCTAssertTrue(session.isPrivacyCurtainVisible)
        XCTAssertFalse(session.isAuthenticating)
        XCTAssertNil(session.authenticationMessage)
    }

    func testVaultAuthenticationUnlocksVaultAndStartsFreshAccess() async {
        let authenticator = MockDeviceAuthenticator()
        let sleeper = ControllableAsyncSleeper()
        let session = makeSession(authenticator: authenticator, sleeper: sleeper)

        session.authenticateToUnlockVault()
        XCTAssertTrue(session.isAuthenticating)
        XCTAssertFalse(session.isVaultUnlocked)

        authenticator.completeOldest(success: true)
        await settle()

        XCTAssertTrue(session.isVaultUnlocked)
        XCTAssertTrue(session.isSensitiveAccessFresh)
        XCTAssertFalse(session.isPrivacyCurtainVisible)
        XCTAssertFalse(session.isAuthenticating)
        await sleeper.waitUntilSleeping()
        let duration = await sleeper.requestedDuration(at: 0)
        XCTAssertEqual(duration, AuthenticationSession.sensitiveAccessDuration)
    }

    func testFailedAndUnavailableAuthenticationLeaveVaultLocked() async {
        let authenticator = MockDeviceAuthenticator()
        let session = makeSession(authenticator: authenticator)

        session.authenticateToUnlockVault()
        authenticator.completeOldest(success: false)
        await settle()

        XCTAssertFalse(session.isVaultUnlocked)
        XCTAssertFalse(session.isAuthenticating)
        XCTAssertNotNil(session.authenticationMessage)

        authenticator.canEvaluate = false
        session.authenticateToUnlockVault()

        XCTAssertFalse(session.isVaultUnlocked)
        XCTAssertFalse(session.isAuthenticating)
        XCTAssertEqual(session.authenticationMessage, "Authentication isn’t available on this device.")
    }

    func testBackgroundImmediatelyCoversAndRevokesSensitiveAccess() async {
        let authenticator = MockDeviceAuthenticator()
        let session = makeSession(authenticator: authenticator)
        await unlock(session, with: authenticator)

        session.didEnterBackground()

        XCTAssertTrue(session.isVaultUnlocked)
        XCTAssertFalse(session.isSensitiveAccessFresh)
        XCTAssertTrue(session.isPrivacyCurtainVisible)
    }

    func testReturnAtGraceBoundaryKeepsVaultOpenWithoutPrompt() async {
        let authenticator = MockDeviceAuthenticator()
        let session = makeSession(authenticator: authenticator)
        await unlock(session, with: authenticator)
        let now = ContinuousClock().now

        session.didEnterBackground(at: now)
        session.didBecomeActive(
            vaultLockEnabled: true,
            at: now.advanced(by: .seconds(60))
        )

        XCTAssertTrue(session.isVaultUnlocked)
        XCTAssertFalse(session.isSensitiveAccessFresh)
        XCTAssertFalse(session.isPrivacyCurtainVisible)
        XCTAssertFalse(session.isAuthenticating)
        XCTAssertEqual(authenticator.evaluateCount, 1)
    }

    func testReturnAfterGraceLocksAndStartsNewAuthentication() async {
        let authenticator = MockDeviceAuthenticator()
        let session = makeSession(authenticator: authenticator)
        await unlock(session, with: authenticator)
        let now = ContinuousClock().now

        session.didEnterBackground(at: now)
        session.didBecomeActive(
            vaultLockEnabled: true,
            at: now.advanced(by: .seconds(61))
        )

        XCTAssertFalse(session.isVaultUnlocked)
        XCTAssertFalse(session.isSensitiveAccessFresh)
        XCTAssertTrue(session.isAuthenticating)
        XCTAssertEqual(authenticator.evaluateCount, 2)
    }

    func testSensitiveAccessExpiresWithoutLockingVault() async {
        let authenticator = MockDeviceAuthenticator()
        let sleeper = ControllableAsyncSleeper()
        let session = makeSession(authenticator: authenticator, sleeper: sleeper)
        session.didBecomeActive(vaultLockEnabled: false)

        session.authenticateForSensitiveAccess(reason: "Test")
        authenticator.completeOldest(success: true)
        await settle()
        await sleeper.waitUntilSleeping()

        XCTAssertTrue(session.isSensitiveAccessFresh)
        await sleeper.advance()
        await settle()

        XCTAssertFalse(session.isSensitiveAccessFresh)
        XCTAssertTrue(session.isVaultUnlocked)
    }

    func testFreshSensitiveAccessDoesNotPromptAgain() async {
        let authenticator = MockDeviceAuthenticator()
        let session = makeSession(authenticator: authenticator)
        await unlock(session, with: authenticator)
        var completionValue: Bool?

        session.authenticateForSensitiveAccess(reason: "Test") {
            completionValue = $0
        }

        XCTAssertEqual(completionValue, true)
        XCTAssertEqual(authenticator.evaluateCount, 1)
    }

    func testBackgroundInvalidatesPendingAuthenticationCallback() async {
        let authenticator = MockDeviceAuthenticator()
        let session = makeSession(authenticator: authenticator)

        session.authenticateToUnlockVault()
        session.didEnterBackground()
        XCTAssertEqual(authenticator.invalidateCount, 1)

        authenticator.completeOldest(success: true)
        await settle()

        XCTAssertFalse(session.isVaultUnlocked)
        XCTAssertFalse(session.isSensitiveAccessFresh)
        XCTAssertTrue(session.isPrivacyCurtainVisible)
    }

    func testOlderAuthenticationCannotOverrideNewerAttempt() async {
        let authenticator = MockDeviceAuthenticator()
        let session = makeSession(authenticator: authenticator)

        session.authenticateToUnlockVault()
        session.authenticateToUnlockVault()
        XCTAssertEqual(authenticator.evaluateCount, 2)

        authenticator.completeOldest(success: true)
        await settle()
        XCTAssertFalse(session.isVaultUnlocked)

        authenticator.completeOldest(success: true)
        await settle()
        XCTAssertTrue(session.isVaultUnlocked)
    }

    func testVaultSettingTransitionsDoNotDisableCVVProtection() {
        let session = makeSession()

        session.vaultLockSettingChanged(isEnabled: false)
        XCTAssertTrue(session.isVaultUnlocked)
        XCTAssertFalse(session.isSensitiveAccessFresh)
        XCTAssertFalse(session.isPrivacyCurtainVisible)

        session.vaultLockSettingChanged(isEnabled: true)
        XCTAssertFalse(session.isVaultUnlocked)
        XCTAssertFalse(session.isSensitiveAccessFresh)
    }

    func testSensitiveTimerFailureFailsClosed() async {
        let authenticator = MockDeviceAuthenticator()
        let sleeper = ControllableAsyncSleeper()
        let session = makeSession(authenticator: authenticator, sleeper: sleeper)

        session.authenticateForSensitiveAccess(reason: "Test")
        authenticator.completeOldest(success: true)
        await settle()
        await sleeper.waitUntilSleeping()

        let accessRevoked = expectation(description: "Sensitive access is revoked")
        let cancellable = session.$isSensitiveAccessFresh
            .dropFirst()
            .first(where: { !$0 })
            .sink { _ in accessRevoked.fulfill() }
        await sleeper.fail()
        await fulfillment(of: [accessRevoked], timeout: 1)

        XCTAssertFalse(session.isSensitiveAccessFresh)
        withExtendedLifetime(cancellable) {}
    }

    private func makeSession(
        authenticator: MockDeviceAuthenticator = MockDeviceAuthenticator(),
        sleeper: AsyncSleeper = TaskAsyncSleeper()
    ) -> AuthenticationSession {
        AuthenticationSession(
            authenticatorFactory: MockDeviceAuthenticatorFactory(authenticator),
            sleeper: sleeper
        )
    }

    private func unlock(
        _ session: AuthenticationSession,
        with authenticator: MockDeviceAuthenticator
    ) async {
        session.authenticateToUnlockVault()
        authenticator.completeOldest(success: true)
        await settle()
        XCTAssertTrue(session.isVaultUnlocked)
    }

    private func settle() async {
        for _ in 0..<4 {
            await Task.yield()
        }
    }
}

private final class MockDeviceAuthenticator: DeviceAuthenticating {
    var canEvaluate = true
    private(set) var evaluateCount = 0
    private(set) var invalidateCount = 0
    private var pendingReplies: [(Bool) -> Void] = []

    func canEvaluateDeviceOwnerAuthentication() -> Bool {
        canEvaluate
    }

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
        pendingReplies.removeFirst()(success)
    }
}

private struct MockDeviceAuthenticatorFactory: DeviceAuthenticatorFactory {
    let authenticator: DeviceAuthenticating

    init(_ authenticator: DeviceAuthenticating) {
        self.authenticator = authenticator
    }

    func makeAuthenticator() -> DeviceAuthenticating {
        authenticator
    }
}

actor ControllableAsyncSleeper: AsyncSleeper {
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var waiterOrder: [UUID] = []
    private var requestedDurations: [Duration] = []
    private var cumulativeRegisteredCount = 0
    private var sleepingBarriers: [(Int, CheckedContinuation<Void, Never>)] = []

    func sleep(for duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters[id] = continuation
                waiterOrder.append(id)
                requestedDurations.append(duration)
                cumulativeRegisteredCount += 1
                resumeBarriers()
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
    }

    func waitUntilSleeping(count: Int = 1) async {
        if cumulativeRegisteredCount >= count { return }
        await withCheckedContinuation { continuation in
            sleepingBarriers.append((count, continuation))
        }
    }

    func requestedDuration(at index: Int) -> Duration? {
        requestedDurations.indices.contains(index) ? requestedDurations[index] : nil
    }

    func advance() async {
        finishFirst(with: .success(()))
        await Task.yield()
    }

    func fail() async {
        finishFirst(with: .failure(TestSleeperError.failed))
        await Task.yield()
    }

    private func cancel(id: UUID) {
        guard let continuation = waiters.removeValue(forKey: id) else { return }
        waiterOrder.removeAll { $0 == id }
        continuation.resume(throwing: CancellationError())
    }

    private func finishFirst(with result: Result<Void, Error>) {
        guard let id = waiterOrder.first,
              let continuation = waiters.removeValue(forKey: id) else { return }
        waiterOrder.removeFirst()
        continuation.resume(with: result)
    }

    private func resumeBarriers() {
        var pending: [(Int, CheckedContinuation<Void, Never>)] = []
        for (count, continuation) in sleepingBarriers {
            if cumulativeRegisteredCount >= count {
                continuation.resume()
            } else {
                pending.append((count, continuation))
            }
        }
        sleepingBarriers = pending
    }
}

private enum TestSleeperError: Error {
    case failed
}
