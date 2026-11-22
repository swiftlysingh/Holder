import XCTest
@testable import Holder

@MainActor
final class SupportPromptPolicyTests: XCTestCase {
    private let savedCardID = UUID()

    func testFirstUneditedScanWaitsForSavedDetailsAndShowsOnce() throws {
        let storage = try makeStorage()
        let policy = SupportPromptPolicy(storage: storage)

        XCTAssertFalse(policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 1))
        XCTAssertTrue(policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 2))
        XCTAssertFalse(policy.claim(.tip(.firstScanSaved), version: "2.6", hasPurchasedTip: false))

        policy.showedCardDetails(id: UUID())
        policy.returnedFromCardDetails()
        XCTAssertNil(policy.nextPrompt(version: "2.6", canPresent: true))

        policy.leftCardList()
        policy.showedCardDetails(id: savedCardID)
        policy.showedCardDetails(id: UUID())
        XCTAssertNil(policy.nextPrompt(version: "2.6", canPresent: true))
        policy.returnedFromCardDetails()
        XCTAssertEqual(policy.nextPrompt(version: "2.6", canPresent: true), .tip(.firstScanSaved))
        XCTAssertTrue(policy.claim(.tip(.firstScanSaved), version: "2.6", hasPurchasedTip: false))
        XCTAssertFalse(policy.claim(.tip(.firstScanSaved), version: "2.6", hasPurchasedTip: false))
        policy.dismissAutomaticTip(try XCTUnwrap(policy.automaticTip))

        let nextLaunch = SupportPromptPolicy(storage: storage)
        nextLaunch.returnedFromCardDetails()
        XCTAssertNil(nextLaunch.nextPrompt(version: "2.6", canPresent: true))
        XCTAssertFalse(nextLaunch.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 4))
    }

    func testThirdSaveSurvivesLaunchAndAnUneditedThirdScanTakesPriority() throws {
        let storage = try makeStorage()
        let policy = SupportPromptPolicy(storage: storage)

        XCTAssertFalse(policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 2))
        XCTAssertTrue(policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 3))
        XCTAssertNil(policy.nextPrompt(version: "2.6", canPresent: true))
        XCTAssertFalse(policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 4))

        let nextLaunch = SupportPromptPolicy(storage: storage)
        XCTAssertNil(nextLaunch.nextPrompt(version: "2.6", canPresent: true))
        nextLaunch.returnedFromCardDetails()
        nextLaunch.showedCardDetails(id: UUID())
        nextLaunch.returnedFromCardDetails()
        XCTAssertNil(nextLaunch.nextPrompt(version: "2.6", canPresent: true))
        returnFromSavedCard(in: nextLaunch)
        XCTAssertEqual(nextLaunch.nextPrompt(version: "2.6", canPresent: true), .tip(.thirdCardSaved))

        let scanner = SupportPromptPolicy(storage: try makeStorage())
        XCTAssertTrue(scanner.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 3))
        returnFromSavedCard(in: scanner)
        XCTAssertEqual(scanner.nextPrompt(version: "2.6", canPresent: true), .tip(.firstScanSaved))

        let establishedUser = SupportPromptPolicy(storage: try makeStorage())
        XCTAssertTrue(establishedUser.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 6))
    }

    func testSavedDetailsPrerequisiteSurvivesRelaunch() throws {
        let unseenStorage = try makeStorage()
        let unseen = SupportPromptPolicy(storage: unseenStorage)
        XCTAssertTrue(unseen.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 1))
        unseen.endForegroundSession()

        let relaunchedUnseen = SupportPromptPolicy(storage: unseenStorage)
        XCTAssertNil(relaunchedUnseen.nextPrompt(version: "2.6", canPresent: true))
        relaunchedUnseen.returnedFromCardDetails()
        relaunchedUnseen.showedCardDetails(id: UUID())
        relaunchedUnseen.returnedFromCardDetails()
        XCTAssertNil(relaunchedUnseen.nextPrompt(version: "2.6", canPresent: true))
        relaunchedUnseen.showedCardDetails(id: savedCardID)
        XCTAssertNil(relaunchedUnseen.nextPrompt(version: "2.6", canPresent: true))
        relaunchedUnseen.returnedFromCardDetails()
        XCTAssertEqual(relaunchedUnseen.nextPrompt(version: "2.6", canPresent: true), .tip(.firstScanSaved))

        let seenStorage = try makeStorage()
        let seen = SupportPromptPolicy(storage: seenStorage)
        XCTAssertTrue(seen.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 3))
        seen.showedCardDetails(id: savedCardID)
        XCTAssertNil(seen.nextPrompt(version: "2.6", canPresent: true))

        let relaunchedSeen = SupportPromptPolicy(storage: seenStorage)
        XCTAssertEqual(relaunchedSeen.nextPrompt(version: "2.6", canPresent: true), .tip(.thirdCardSaved))

        let returnedStorage = try makeStorage()
        let returned = SupportPromptPolicy(storage: returnedStorage)
        XCTAssertTrue(returned.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 4))
        returnFromSavedCard(in: returned)
        let relaunchedReturned = SupportPromptPolicy(storage: returnedStorage)
        XCTAssertEqual(relaunchedReturned.nextPrompt(version: "2.6", canPresent: true), .tip(.thirdCardSaved))
    }

    func testFailedTipKeepsItPendingAndKnownPurchaserConsumesIt() throws {
        let storage = try makeStorage()
        recordThreeCopyDays(in: storage)
        let policy = SupportPromptPolicy(storage: storage)
        policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 1)
        returnFromSavedCard(in: policy)

        XCTAssertFalse(policy.claim(.tip(.firstScanSaved), version: "2.6", hasPurchasedTip: nil))
        XCTAssertFalse(policy.claim(.review, version: "2.6"))
        policy.endForegroundSession()
        policy.returnedFromCardDetails()
        XCTAssertTrue(policy.claim(.tip(.firstScanSaved), version: "2.6", hasPurchasedTip: false))
        let failedAttempt = try XCTUnwrap(policy.automaticTip)
        policy.endForegroundSession()
        policy.returnedFromCardDetails()
        XCTAssertEqual(policy.nextPrompt(version: "2.6", canPresent: true), .tip(.firstScanSaved))

        XCTAssertTrue(policy.claim(.tip(.firstScanSaved), version: "2.6", hasPurchasedTip: false))
        policy.dismissAutomaticTip(failedAttempt)
        XCTAssertNotNil(policy.automaticTip)
        policy.endForegroundSession()
        policy.returnedFromCardDetails()
        XCTAssertFalse(policy.claim(.tip(.firstScanSaved), version: "2.6", hasPurchasedTip: true))

        let nextLaunch = SupportPromptPolicy(storage: storage)
        nextLaunch.returnedFromCardDetails()
        XCTAssertEqual(
            nextLaunch.nextPrompt(version: "2.6", canPresent: true),
            .review,
            "A purchased tip stays consumed, so a later card-list visit can ask for a rating"
        )
    }

    func testPresentationAvailabilityBlocksBothPrompts() throws {
        let storage = try makeStorage()
        recordThreeCopyDays(in: storage)
        let policy = SupportPromptPolicy(storage: storage)
        policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 1)
        returnFromSavedCard(in: policy)

        XCTAssertNil(policy.nextPrompt(version: "2.6", canPresent: false))
        XCTAssertEqual(policy.nextPrompt(version: "2.6", canPresent: true), .tip(.firstScanSaved))
        XCTAssertEqual(policy.nextPrompt(version: "2.6", canPresent: true, tipsEnabled: false), .review)
    }

    func testCopyAndShareDeferTipUntilNextSessionAndCardListReturn() throws {
        let policy = SupportPromptPolicy(storage: try makeStorage())
        policy.recordNewCardSaved(id: savedCardID, scanNumberUnedited: false, activeCardCount: 3)
        policy.recordCopy()
        returnFromSavedCard(in: policy)
        XCTAssertFalse(policy.claim(.tip(.thirdCardSaved), version: "2.6", hasPurchasedTip: false))

        policy.endForegroundSession()
        XCTAssertNil(policy.nextPrompt(version: "2.6", canPresent: true))
        policy.recordShare()
        policy.returnedFromCardDetails()
        XCTAssertFalse(policy.claim(.tip(.thirdCardSaved), version: "2.6", hasPurchasedTip: false))

        policy.endForegroundSession()
        policy.returnedFromCardDetails()
        XCTAssertEqual(policy.nextPrompt(version: "2.6", canPresent: true), .tip(.thirdCardSaved))
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
        XCTAssertFalse(nextLaunch.claim(.review, version: "2.6"))

        now += 86_400
        copyingSession.recordCopy()
        copyingSession.returnedFromCardDetails()
        XCTAssertFalse(copyingSession.claim(.review, version: "2.6"))
        copyingSession.endForegroundSession()
        XCTAssertFalse(copyingSession.claim(.review, version: "2.6"))
        copyingSession.returnedFromCardDetails()
        XCTAssertTrue(copyingSession.claim(.review, version: "2.6"))

        let updatedApp = SupportPromptPolicy(storage: storage)
        updatedApp.returnedFromCardDetails()
        XCTAssertFalse(updatedApp.claim(.review, version: "2.6"))
        XCTAssertTrue(updatedApp.claim(.review, version: "2.7"))
    }

    func testManualAndAutomaticTipBlockReviewAndReviewBlocksTipInItsSession() throws {
        let storage = try makeStorage()
        recordThreeCopyDays(in: storage)

        let manual = SupportPromptPolicy(storage: storage)
        manual.recordNewCardSaved(id: savedCardID, scanNumberUnedited: true, activeCardCount: 1)
        manual.recordTipPresented()
        returnFromSavedCard(in: manual)
        XCTAssertFalse(manual.claim(.review, version: "2.6"))
        XCTAssertNil(manual.nextPrompt(version: "2.6", canPresent: true))

        let review = SupportPromptPolicy(storage: storage)
        review.returnedFromCardDetails()
        XCTAssertTrue(review.claim(.review, version: "2.6"))
        XCTAssertFalse(review.claim(.tip(.firstScanSaved), version: "2.6", hasPurchasedTip: false))

        let automatic = SupportPromptPolicy(storage: storage)
        automatic.returnedFromCardDetails()
        XCTAssertTrue(automatic.claim(.tip(.firstScanSaved), version: "2.6", hasPurchasedTip: false))
        XCTAssertFalse(automatic.claim(.review, version: "2.7"))
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
