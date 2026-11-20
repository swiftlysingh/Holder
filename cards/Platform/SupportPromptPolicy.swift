import Foundation
import SwiftUI

@MainActor
@Observable
final class SupportPromptPolicy {
    enum TipSource: String {
        case firstScanSaved = "first_scan_saved"
        case thirdCardSaved = "third_card_saved"
    }

    struct AutomaticTip: Identifiable, Equatable {
        let id = UUID()
        let source: TipSource
    }

    enum TipPurchaseStatus {
        case unknown
        case purchased
        case notPurchased
    }

    struct PresentationContext {
        var isVaultUnlocked: Bool
        var isActive: Bool
        var isUnlocking: Bool
        var isOnboarding: Bool
        var isOnCardList: Bool
        var isAddingOrScanning: Bool
        var hasModal: Bool

        var permitsPrompt: Bool { isActive && canStayOnCardList }

        var canStayOnCardList: Bool {
            isVaultUnlocked && !isUnlocking && !isOnboarding && isOnCardList
                && !isAddingOrScanning && !hasModal
        }
    }

    private enum Key {
        static let tip = "supportPrompt.tip"
        static let tipDetailsSeen = "supportPrompt.tipDetailsSeen"
        /// Identifies which details screen still has to appear. This is not the card number.
        static let tipCardID = "supportPrompt.tipCardID"
        static let copyDays = "supportPrompt.copyDays"
        static let reviewedVersions = "supportPrompt.reviewedVersions"
    }

    private let storage: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar
    private var pendingTip: TipSource?
    private var tipWasConsumed: Bool
    /// Card whose details must appear before the tip can be offered. Nil once they have.
    private var savedTipCardID: UUID?
    private var detailsPrerequisiteCompleted: Bool
    /// True when a previous launch already showed the saved card, so this launch can offer the tip from the list.
    private var detailsCompletedBeforeSession: Bool
    private var returnedToCardList = false
    private var copyDays: [String]
    private var reviewedVersions: [String]
    private var usedCardDetailsThisSession = false
    private var attemptedTipThisSession = false
    private var requestedReviewThisSession = false
    private(set) var automaticTip: AutomaticTip?

    init(
        storage: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.storage = storage
        self.now = now
        self.calendar = calendar

        let tip = storage.string(forKey: Key.tip)
        let pendingTip = tip.flatMap(TipSource.init(rawValue:))
        let detailsSeen = pendingTip != nil && storage.bool(forKey: Key.tipDetailsSeen)
        self.pendingTip = pendingTip
        tipWasConsumed = tip == "consumed"
        detailsPrerequisiteCompleted = detailsSeen
        detailsCompletedBeforeSession = detailsSeen
        savedTipCardID = detailsSeen ? nil : storage.string(forKey: Key.tipCardID).flatMap(UUID.init(uuidString:))
        copyDays = storage.stringArray(forKey: Key.copyDays) ?? []
        reviewedVersions = storage.stringArray(forKey: Key.reviewedVersions) ?? []
    }

    @discardableResult
    func recordNewCardSaved(id: UUID, scanNumberUnedited: Bool, activeCardCount: Int) -> Bool {
        guard !tipWasConsumed, pendingTip == nil else { return false }
        let source: TipSource
        if scanNumberUnedited {
            source = .firstScanSaved
        } else if activeCardCount >= 3 {
            source = .thirdCardSaved
        } else {
            return false
        }

        savedTipCardID = id
        detailsPrerequisiteCompleted = false
        detailsCompletedBeforeSession = false
        returnedToCardList = false
        pendingTip = source
        storage.set(source.rawValue, forKey: Key.tip)
        storage.set(false, forKey: Key.tipDetailsSeen)
        storage.set(id.uuidString, forKey: Key.tipCardID)
        return true
    }

    func showedCardDetails(id: UUID) {
        guard savedTipCardID == id else { return }
        storage.set(true, forKey: Key.tipDetailsSeen)
        storage.removeObject(forKey: Key.tipCardID)
        savedTipCardID = nil
        detailsPrerequisiteCompleted = true
        returnedToCardList = false
    }

    func returnedFromCardDetails() {
        returnedToCardList = true
    }

    func leftCardList() {
        returnedToCardList = false
        automaticTip = nil
    }

    func endForegroundSession() {
        leftCardList()
        usedCardDetailsThisSession = false
        attemptedTipThisSession = false
        requestedReviewThisSession = false
    }

    func eligibleTip(in context: PresentationContext) -> TipSource? {
        let settledOnCardList = returnedToCardList || detailsCompletedBeforeSession
        guard context.permitsPrompt, detailsPrerequisiteCompleted, savedTipCardID == nil, settledOnCardList,
              !usedCardDetailsThisSession, !attemptedTipThisSession,
              !requestedReviewThisSession else { return nil }
        return pendingTip
    }

    @discardableResult
    func beginAutomaticTip(
        _ source: TipSource,
        purchaseStatus: TipPurchaseStatus,
        in context: PresentationContext
    ) -> Bool {
        guard eligibleTip(in: context) == source else { return false }
        switch purchaseStatus {
        case .unknown:
            attemptedTipThisSession = true
            return false
        case .purchased:
            returnedToCardList = false
            consumeTip()
            return false
        case .notPurchased:
            attemptedTipThisSession = true
            automaticTip = AutomaticTip(source: source)
            return true
        }
    }

    func confirmAutomaticTip(_ attempt: AutomaticTip) {
        guard automaticTip == attempt, !tipWasConsumed else { return }
        consumeTip()
    }

    func dismissAutomaticTip(_ attempt: AutomaticTip) {
        guard automaticTip == attempt else { return }
        confirmAutomaticTip(attempt)
        automaticTip = nil
    }

    private func consumeTip() {
        tipWasConsumed = true
        pendingTip = nil
        savedTipCardID = nil
        storage.set("consumed", forKey: Key.tip)
        storage.removeObject(forKey: Key.tipDetailsSeen)
        storage.removeObject(forKey: Key.tipCardID)
    }

    func recordTipPresented() {
        attemptedTipThisSession = true
    }

    func recordShare() {
        guard !usedCardDetailsThisSession else { return }
        usedCardDetailsThisSession = true
        leftCardList()
    }

    func recordCopy() {
        recordShare()
        guard copyDays.count < 3 else { return }
        let date = calendar.dateComponents([.era, .year, .month, .day], from: now())
        guard let era = date.era, let year = date.year, let month = date.month, let day = date.day else { return }
        let key = "\(era)-\(year)-\(month)-\(day)"
        guard !copyDays.contains(key) else { return }
        copyDays.append(key)
        storage.set(copyDays, forKey: Key.copyDays)
    }

    func canRequestReview(version: String, in context: PresentationContext) -> Bool {
        context.permitsPrompt && returnedToCardList && !version.isEmpty && copyDays.count >= 3
            && !reviewedVersions.contains(version) && !usedCardDetailsThisSession && !attemptedTipThisSession
            && !requestedReviewThisSession
    }

    func claimReview(version: String, in context: PresentationContext) -> Bool {
        guard canRequestReview(version: version, in: context) else { return false }
        requestedReviewThisSession = true
        reviewedVersions.append(version)
        storage.set(reviewedVersions, forKey: Key.reviewedVersions)
        return true
    }
}

extension EnvironmentValues {
    @Entry var supportPromptPolicy: SupportPromptPolicy?
}
