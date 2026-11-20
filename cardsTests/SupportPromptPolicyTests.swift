import XCTest
@testable import Holder

@MainActor
final class SupportPromptPolicyTests: XCTestCase {
    private let savedCardID = UUID()
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

        XCTAssertFalse(policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 1))
        XCTAssertTrue(policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 2))
        XCTAssertFalse(policy.beginAutomaticTip(.firstScanSaved, purchaseStatus: .notPurchased, in: ready))

        policy.showedCardDetails(id: UUID())
        policy.returnedFromCardDetails()
        XCTAssertNil(policy.eligibleTip(in: ready))

        policy.leftCardList()
        policy.showedCardDetails(id: savedCardID)
        policy.showedCardDetails(id: UUID())
        XCTAssertNil(policy.eligibleTip(in: ready))
        policy.returnedFromCardDetails()
        XCTAssertEqual(policy.eligibleTip(in: ready), .firstScanSaved)
        XCTAssertTrue(policy.beginAutomaticTip(.firstScanSaved, purchaseStatus: .notPurchased, in: ready))
        XCTAssertFalse(policy.beginAutomaticTip(.firstScanSaved, purchaseStatus: .notPurchased, in: ready))
        policy.dismissAutomaticTip(try XCTUnwrap(policy.automaticTip))

        let nextLaunch = SupportPromptPolicy(storage: storage)
        nextLaunch.returnedFromCardDetails()
        XCTAssertNil(nextLaunch.eligibleTip(in: ready))
        XCTAssertFalse(nextLaunch.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 4))
    }

    func testThirdSaveSurvivesLaunchAndAnUneditedThirdScanTakesPriority() throws {
        let storage = try makeStorage()
        let policy = SupportPromptPolicy(storage: storage)

        XCTAssertFalse(policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 2))
        XCTAssertTrue(policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 3))
        XCTAssertNil(policy.eligibleTip(in: ready))
        XCTAssertFalse(policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 4))

        let nextLaunch = SupportPromptPolicy(storage: storage)
        XCTAssertNil(nextLaunch.eligibleTip(in: ready))
        nextLaunch.returnedFromCardDetails()
        nextLaunch.showedCardDetails(id: UUID())
        nextLaunch.returnedFromCardDetails()
        XCTAssertNil(nextLaunch.eligibleTip(in: ready))
        returnFromSavedCard(in: nextLaunch)
        XCTAssertEqual(nextLaunch.eligibleTip(in: ready), .thirdCardSaved)

        let scanner = SupportPromptPolicy(storage: try makeStorage())
        XCTAssertTrue(scanner.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 3))
        returnFromSavedCard(in: scanner)
        XCTAssertEqual(scanner.eligibleTip(in: ready), .firstScanSaved)

        let establishedUser = SupportPromptPolicy(storage: try makeStorage())
        XCTAssertTrue(establishedUser.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 6))
    }

    func testSavedDetailsPrerequisiteSurvivesRelaunch() throws {
        let unseenStorage = try makeStorage()
        let unseen = SupportPromptPolicy(storage: unseenStorage)
        XCTAssertTrue(unseen.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 1))
        unseen.endForegroundSession()

        let relaunchedUnseen = SupportPromptPolicy(storage: unseenStorage)
        XCTAssertNil(relaunchedUnseen.eligibleTip(in: ready))
        relaunchedUnseen.returnedFromCardDetails()
        relaunchedUnseen.showedCardDetails(id: UUID())
        relaunchedUnseen.returnedFromCardDetails()
        XCTAssertNil(relaunchedUnseen.eligibleTip(in: ready))
        relaunchedUnseen.showedCardDetails(id: savedCardID)
        XCTAssertNil(relaunchedUnseen.eligibleTip(in: ready))
        relaunchedUnseen.returnedFromCardDetails()
        XCTAssertEqual(relaunchedUnseen.eligibleTip(in: ready), .firstScanSaved)

        let seenStorage = try makeStorage()
        let seen = SupportPromptPolicy(storage: seenStorage)
        XCTAssertTrue(seen.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 3))
        seen.showedCardDetails(id: savedCardID)
        XCTAssertNil(seen.eligibleTip(in: ready))

        let relaunchedSeen = SupportPromptPolicy(storage: seenStorage)
        XCTAssertEqual(relaunchedSeen.eligibleTip(in: ready), .thirdCardSaved)

        let returnedStorage = try makeStorage()
        let returned = SupportPromptPolicy(storage: returnedStorage)
        XCTAssertTrue(returned.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 4))
        returnFromSavedCard(in: returned)
        let relaunchedReturned = SupportPromptPolicy(storage: returnedStorage)
        XCTAssertEqual(relaunchedReturned.eligibleTip(in: ready), .thirdCardSaved)
    }

    func testFailedTipKeepsItPendingAndKnownPurchaserConsumesIt() throws {
        let storage = try makeStorage()
        recordThreeCopyDays(in: storage)
        let policy = SupportPromptPolicy(storage: storage)
        policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 1)
        returnFromSavedCard(in: policy)

        XCTAssertFalse(policy.beginAutomaticTip(.firstScanSaved, purchaseStatus: .unknown, in: ready))
        XCTAssertFalse(policy.claimReview(version: "2.6", in: ready))
        policy.endForegroundSession()
        policy.returnedFromCardDetails()
        XCTAssertTrue(policy.beginAutomaticTip(.firstScanSaved, purchaseStatus: .notPurchased, in: ready))
        let failedAttempt = try XCTUnwrap(policy.automaticTip)
        policy.endForegroundSession()
        policy.returnedFromCardDetails()
        XCTAssertEqual(policy.eligibleTip(in: ready), .firstScanSaved)

        XCTAssertTrue(policy.beginAutomaticTip(.firstScanSaved, purchaseStatus: .notPurchased, in: ready))
        policy.dismissAutomaticTip(failedAttempt)
        XCTAssertNotNil(policy.automaticTip)
        policy.endForegroundSession()
        policy.returnedFromCardDetails()
        XCTAssertFalse(policy.beginAutomaticTip(.firstScanSaved, purchaseStatus: .purchased, in: ready))

        let nextLaunch = SupportPromptPolicy(storage: storage)
        nextLaunch.returnedFromCardDetails()
        XCTAssertNil(nextLaunch.eligibleTip(in: ready))
    }

    func testBothPromptsRespectEveryPresentationGuard() throws {
        let storage = try makeStorage()
        recordThreeCopyDays(in: storage)
        let policy = SupportPromptPolicy(storage: storage)
        policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 1)
        returnFromSavedCard(in: policy)

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
            XCTAssertFalse(policy.beginAutomaticTip(.firstScanSaved, purchaseStatus: .notPurchased, in: blocked), "\(keyPath)")
            XCTAssertFalse(policy.claimReview(version: "2.6", in: blocked), "\(keyPath)")
        }
        XCTAssertEqual(policy.eligibleTip(in: ready), .firstScanSaved)
        XCTAssertTrue(policy.canRequestReview(version: "2.6", in: ready))
    }

    func testCopyAndShareDeferTipUntilNextSessionAndCardListReturn() throws {
        let policy = SupportPromptPolicy(storage: try makeStorage())
        policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 3)
        policy.recordCopy()
        returnFromSavedCard(in: policy)
        XCTAssertFalse(policy.beginAutomaticTip(.thirdCardSaved, purchaseStatus: .notPurchased, in: ready))

        policy.endForegroundSession()
        XCTAssertNil(policy.eligibleTip(in: ready))
        policy.recordShare()
        policy.returnedFromCardDetails()
        XCTAssertFalse(policy.beginAutomaticTip(.thirdCardSaved, purchaseStatus: .notPurchased, in: ready))

        policy.endForegroundSession()
        policy.returnedFromCardDetails()
        XCTAssertEqual(policy.eligibleTip(in: ready), .thirdCardSaved)
    }

    func testReviewRequiresThreeDistinctCopyDaysAndIsClaimedOncePerVersion() throws {
        let storage = try makeStorage()
        var now = Date(timeIntervalSince1970: 0)
        let copyingSession = SupportPromptPolicy(storage: storage, now: { now }, calendar: utc)
        copyingSession.recordCopy()
        copyingSession.recordCopy()
        now += 86_400
        copyingSession.recordCopy()
        let nextLaunch = SupportPromptPolicy(storage: storage)
        nextLaunch.returnedFromCardDetails()
        XCTAssertFalse(nextLaunch.claimReview(version: "2.6", in: ready))

        now += 86_400
        copyingSession.recordCopy()
        copyingSession.returnedFromCardDetails()
        XCTAssertFalse(copyingSession.claimReview(version: "2.6", in: ready))
        copyingSession.endForegroundSession()
        XCTAssertFalse(copyingSession.claimReview(version: "2.6", in: ready))
        copyingSession.returnedFromCardDetails()
        XCTAssertTrue(copyingSession.claimReview(version: "2.6", in: ready))

        let updatedApp = SupportPromptPolicy(storage: storage)
        updatedApp.returnedFromCardDetails()
        XCTAssertFalse(updatedApp.claimReview(version: "2.6", in: ready))
        XCTAssertTrue(updatedApp.claimReview(version: "2.7", in: ready))
    }

    func testManualAndAutomaticTipBlockReviewAndReviewBlocksTipInItsSession() throws {
        let storage = try makeStorage()
        recordThreeCopyDays(in: storage)

        let manual = SupportPromptPolicy(storage: storage)
        manual.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 1)
        manual.recordTipPresented()
        returnFromSavedCard(in: manual)
        XCTAssertFalse(manual.claimReview(version: "2.6", in: ready))
        XCTAssertNil(manual.eligibleTip(in: ready))

        let review = SupportPromptPolicy(storage: storage)
        review.returnedFromCardDetails()
        XCTAssertTrue(review.claimReview(version: "2.6", in: ready))
        XCTAssertFalse(review.beginAutomaticTip(.firstScanSaved, purchaseStatus: .notPurchased, in: ready))

        let automatic = SupportPromptPolicy(storage: storage)
        automatic.returnedFromCardDetails()
        XCTAssertTrue(automatic.beginAutomaticTip(.firstScanSaved, purchaseStatus: .notPurchased, in: ready))
        XCTAssertFalse(automatic.claimReview(version: "2.7", in: ready))
    }

    private func returnFromSavedCard(in policy: SupportPromptPolicy) {
        policy.showedCardDetails(id: savedCardID)
        policy.returnedFromCardDetails()
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
