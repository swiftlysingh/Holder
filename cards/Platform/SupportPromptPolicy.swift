import Foundation
import SwiftUI

@MainActor
@Observable
final class SupportPromptPolicy {
    enum TipSource: String, Identifiable {
        case firstScanSaved = "first_scan_saved"
        case thirdCardSaved = "third_card_saved"

        var id: Self { self }
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

        var permitsPrompt: Bool {
            isVaultUnlocked && isActive && !isUnlocking && !isOnboarding && isOnCardList
                && !isAddingOrScanning && !hasModal
        }
    }

    private enum Key {
        static let tip = "supportPrompt.tip"
        static let copyDays = "supportPrompt.copyDays"
        static let reviewedVersions = "supportPrompt.reviewedVersions"
    }

    private let storage: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar
    private var pendingTip: TipSource?
    private var tipWasConsumed: Bool
    private var tipCanBePresented: Bool
    private var copyDays: [String]
    private var reviewedVersions: [String]
    private var usedCardDetailsThisSession = false
    private var showedTipThisSession = false
    private var requestedReviewThisSession = false

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
        self.pendingTip = pendingTip
        tipWasConsumed = tip == "consumed"
        tipCanBePresented = pendingTip != nil
        copyDays = storage.stringArray(forKey: Key.copyDays) ?? []
        reviewedVersions = storage.stringArray(forKey: Key.reviewedVersions) ?? []
    }

    @discardableResult
    func recordNewCardSaved(scanNumberUnedited: Bool, savedCardCount: Int) -> Bool {
        guard !tipWasConsumed, pendingTip == nil else { return false }
        let source: TipSource
        if scanNumberUnedited {
            source = .firstScanSaved
        } else if savedCardCount == 3 {
            source = .thirdCardSaved
        } else {
            return false
        }

        tipCanBePresented = false
        pendingTip = source
        storage.set(source.rawValue, forKey: Key.tip)
        return true
    }

    func returnedFromSavedDetails() {
        tipCanBePresented = true
    }

    func eligibleTip(in context: PresentationContext) -> TipSource? {
        guard context.permitsPrompt, tipCanBePresented, !usedCardDetailsThisSession, !showedTipThisSession,
              !requestedReviewThisSession else { return nil }
        return pendingTip
    }

    func claimTip(
        _ source: TipSource,
        purchaseStatus: TipPurchaseStatus,
        in context: PresentationContext
    ) -> Bool {
        guard eligibleTip(in: context) == source, purchaseStatus != .unknown else { return false }
        tipWasConsumed = true
        pendingTip = nil
        storage.set("consumed", forKey: Key.tip)
        guard purchaseStatus == .notPurchased else { return false }
        recordTipPresented()
        return true
    }

    func recordTipPresented() {
        showedTipThisSession = true
    }

    func recordShare() {
        usedCardDetailsThisSession = true
    }

    func recordCopy() {
        usedCardDetailsThisSession = true
        guard copyDays.count < 3 else { return }
        let date = calendar.dateComponents([.era, .year, .month, .day], from: now())
        guard let era = date.era, let year = date.year, let month = date.month, let day = date.day else { return }
        let key = "\(era)-\(year)-\(month)-\(day)"
        guard !copyDays.contains(key) else { return }
        copyDays.append(key)
        storage.set(copyDays, forKey: Key.copyDays)
    }

    func canRequestReview(version: String, in context: PresentationContext) -> Bool {
        context.permitsPrompt && !version.isEmpty && copyDays.count >= 3 && !reviewedVersions.contains(version)
            && !usedCardDetailsThisSession && !showedTipThisSession && !requestedReviewThisSession
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
