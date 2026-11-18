import XCTest
@testable import Holder

@MainActor
final class SupportPromptPolicyTests: XCTestCase {
    private let ready = SupportPromptPolicy.PresentationContext(
        isVaultUnlocked: true,
        isActive: true,
        isUnlocking: false,
        isOnboarding: false,
        isOnCardList: true,
        isAddingOrScanning: false,
        hasModal: false
    )

    func testFirstUneditedScanWaitsForSavedDetailsAndShowsOnce() throws {
        let storage = try makeStorage()
        let policy = SupportPromptPolicy(storage: storage)

        XCTAssertFalse(policy.recordNewCardSaved(scanNumberUnedited: false, savedCardCount: 1))
        XCTAssertTrue(policy.recordNewCardSaved(scanNumberUnedited: true, savedCardCount: 2))
        XCTAssertNil(policy.eligibleTip(in: ready))
        XCTAssertFalse(policy.claimTip(.firstScanSaved, purchaseStatus: .notPurchased, in: ready))

        policy.returnedFromSavedDetails()
        XCTAssertEqual(policy.eligibleTip(in: ready), .firstScanSaved)
        XCTAssertTrue(policy.claimTip(.firstScanSaved, purchaseStatus: .notPurchased, in: ready))
        XCTAssertFalse(policy.claimTip(.firstScanSaved, purchaseStatus: .notPurchased, in: ready))

        let nextLaunch = SupportPromptPolicy(storage: storage)
        XCTAssertNil(nextLaunch.eligibleTip(in: ready))
        XCTAssertFalse(nextLaunch.recordNewCardSaved(scanNumberUnedited: true, savedCardCount: 4))
    }

    func testThirdSaveSurvivesLaunchAndAnUneditedThirdScanTakesPriority() throws {
        let storage = try makeStorage()
        let policy = SupportPromptPolicy(storage: storage)

        XCTAssertFalse(policy.recordNewCardSaved(scanNumberUnedited: false, savedCardCount: 2))
        XCTAssertTrue(policy.recordNewCardSaved(scanNumberUnedited: false, savedCardCount: 3))
        XCTAssertNil(policy.eligibleTip(in: ready))
        XCTAssertFalse(policy.recordNewCardSaved(scanNumberUnedited: true, savedCardCount: 4))
        XCTAssertEqual(SupportPromptPolicy(storage: storage).eligibleTip(in: ready), .thirdCardSaved)

        let scanner = SupportPromptPolicy(storage: try makeStorage())
        XCTAssertTrue(scanner.recordNewCardSaved(scanNumberUnedited: true, savedCardCount: 3))
        scanner.returnedFromSavedDetails()
        XCTAssertEqual(scanner.eligibleTip(in: ready), .firstScanSaved)
    }

    func testUnknownPurchaseStatusKeepsTipPendingAndKnownPurchaserConsumesIt() throws {
        let storage = try makeStorage()
        let policy = SupportPromptPolicy(storage: storage)
        policy.recordNewCardSaved(scanNumberUnedited: true, savedCardCount: 1)
        policy.returnedFromSavedDetails()

        XCTAssertFalse(policy.claimTip(.firstScanSaved, purchaseStatus: .unknown, in: ready))
        XCTAssertEqual(policy.eligibleTip(in: ready), .firstScanSaved)
        XCTAssertFalse(policy.claimTip(.firstScanSaved, purchaseStatus: .purchased, in: ready))
        XCTAssertNil(SupportPromptPolicy(storage: storage).eligibleTip(in: ready))
    }

    func testBothPromptsRespectEveryPresentationGuard() throws {
        let storage = try makeStorage()
        recordThreeCopyDays(in: storage)
        let policy = SupportPromptPolicy(storage: storage)
        policy.recordNewCardSaved(scanNumberUnedited: true, savedCardCount: 1)
        policy.returnedFromSavedDetails()

        let guards: [(WritableKeyPath<SupportPromptPolicy.PresentationContext, Bool>, Bool)] = [
            (\.isVaultUnlocked, false),
            (\.isActive, false),
            (\.isUnlocking, true),
            (\.isOnboarding, true),
            (\.isOnCardList, false),
            (\.isAddingOrScanning, true),
            (\.hasModal, true)
        ]
        for (keyPath, blockedValue) in guards {
            var blocked = ready
            blocked[keyPath: keyPath] = blockedValue
            XCTAssertFalse(policy.claimTip(.firstScanSaved, purchaseStatus: .notPurchased, in: blocked), "\(keyPath)")
            XCTAssertFalse(policy.claimReview(version: "2.6", in: blocked), "\(keyPath)")
        }
        XCTAssertEqual(policy.eligibleTip(in: ready), .firstScanSaved)
        XCTAssertTrue(policy.canRequestReview(version: "2.6", in: ready))
    }

    func testCopyAndShareDeferTipUntilNextLaunch() throws {
        let storage = try makeStorage()
        let copyingSession = SupportPromptPolicy(storage: storage)
        copyingSession.recordNewCardSaved(scanNumberUnedited: false, savedCardCount: 3)
        copyingSession.recordCopy()
        copyingSession.returnedFromSavedDetails()
        XCTAssertFalse(copyingSession.claimTip(.thirdCardSaved, purchaseStatus: .notPurchased, in: ready))

        let sharingSession = SupportPromptPolicy(storage: storage)
        sharingSession.recordShare()
        XCTAssertFalse(sharingSession.claimTip(.thirdCardSaved, purchaseStatus: .notPurchased, in: ready))

        XCTAssertEqual(SupportPromptPolicy(storage: storage).eligibleTip(in: ready), .thirdCardSaved)
    }

    func testReviewRequiresThreeDistinctCopyDaysAndIsClaimedOncePerVersion() throws {
        let storage = try makeStorage()
        var now = Date(timeIntervalSince1970: 0)
        let copyingSession = SupportPromptPolicy(storage: storage, now: { now }, calendar: utc)
        copyingSession.recordCopy()
        copyingSession.recordCopy()
        now += 86_400
        copyingSession.recordCopy()
        XCTAssertFalse(SupportPromptPolicy(storage: storage).claimReview(version: "2.6", in: ready))

        now += 86_400
        copyingSession.recordCopy()
        XCTAssertFalse(copyingSession.claimReview(version: "2.6", in: ready))
        XCTAssertTrue(SupportPromptPolicy(storage: storage).claimReview(version: "2.6", in: ready))
        XCTAssertFalse(SupportPromptPolicy(storage: storage).claimReview(version: "2.6", in: ready))
        XCTAssertTrue(SupportPromptPolicy(storage: storage).claimReview(version: "2.7", in: ready))
        XCTAssertFalse(SupportPromptPolicy(storage: storage).claimReview(version: "2.6", in: ready))
    }

    func testManualAndAutomaticTipBlockReviewAndReviewBlocksTipInItsSession() throws {
        let storage = try makeStorage()
        recordThreeCopyDays(in: storage)

        let manual = SupportPromptPolicy(storage: storage)
        manual.recordNewCardSaved(scanNumberUnedited: true, savedCardCount: 1)
        manual.recordTipPresented()
        manual.returnedFromSavedDetails()
        XCTAssertFalse(manual.claimReview(version: "2.6", in: ready))
        XCTAssertNil(manual.eligibleTip(in: ready))

        let review = SupportPromptPolicy(storage: storage)
        XCTAssertTrue(review.claimReview(version: "2.6", in: ready))
        XCTAssertFalse(review.claimTip(.firstScanSaved, purchaseStatus: .notPurchased, in: ready))

        let automatic = SupportPromptPolicy(storage: storage)
        XCTAssertTrue(automatic.claimTip(.firstScanSaved, purchaseStatus: .notPurchased, in: ready))
        XCTAssertFalse(automatic.claimReview(version: "2.7", in: ready))
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private func makeStorage() throws -> UserDefaults {
        let name = "SupportPromptPolicyTests.\(UUID())"
        let storage = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        return storage
    }

    private func recordThreeCopyDays(in storage: UserDefaults) {
        var now = Date(timeIntervalSince1970: 0)
        let policy = SupportPromptPolicy(storage: storage, now: { now }, calendar: utc)
        for _ in 0..<3 {
            policy.recordCopy()
            now += 86_400
        }
    }
}
