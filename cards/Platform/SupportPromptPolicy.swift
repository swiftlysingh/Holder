import Foundation
import SwiftUI

@MainActor
@Observable
final class SupportPromptPolicy {
    enum TipSource: String {
        case firstScanSaved = "first_scan_saved"
        case thirdCardSaved = "third_card_saved"
    }

    enum Prompt: Equatable {
        case tip(TipSource)
        case review
    }

    struct AutomaticTip: Identifiable, Equatable {
        let id = UUID()
        let source: TipSource
    }

    private enum Key {
        static let tip = "supportPrompt.tip"
        static let tipDetailsSeen = "supportPrompt.tipDetailsSeen"
        static let tipCardID = "supportPrompt.tipCardID"
        static let copyDays = "supportPrompt.copyDays"
        static let reviewedVersions = "supportPrompt.reviewedVersions"
    }

    private let storage: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar
    private var pendingTip: TipSource?
    private let resumedTip: Bool
    private var returnedToCardList = false
    private var suppressedThisSession = false
    private var copyDays: [String]
    private var reviewedVersions: [String]
    private(set) var automaticTip: AutomaticTip?

    init(
        storage: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.storage = storage
        self.now = now
        self.calendar = calendar
        let pendingTip = storage.string(forKey: Key.tip).flatMap(TipSource.init(rawValue:))
        self.pendingTip = pendingTip
        resumedTip = pendingTip != nil && storage.bool(forKey: Key.tipDetailsSeen)
        copyDays = storage.stringArray(forKey: Key.copyDays) ?? []
        reviewedVersions = storage.stringArray(forKey: Key.reviewedVersions) ?? []
    }

    @discardableResult
    func recordNewCardSaved(id: UUID, scanNumberUnedited: Bool, activeCardCount: Int) -> Bool {
        guard pendingTip == nil, storage.string(forKey: Key.tip) != "consumed",
              scanNumberUnedited || activeCardCount >= 3 else { return false }
        let source: TipSource = scanNumberUnedited ? .firstScanSaved : .thirdCardSaved
        pendingTip = source
        returnedToCardList = false
        storage.set(source.rawValue, forKey: Key.tip)
        storage.set(false, forKey: Key.tipDetailsSeen)
        storage.set(id.uuidString, forKey: Key.tipCardID)
        return true
    }

    func showedCardDetails(id: UUID) {
        guard !storage.bool(forKey: Key.tipDetailsSeen),
              storage.string(forKey: Key.tipCardID).flatMap(UUID.init(uuidString:)) == id else { return }
        returnedToCardList = false
        storage.set(true, forKey: Key.tipDetailsSeen)
        storage.removeObject(forKey: Key.tipCardID)
    }

    func returnedFromCardDetails() {
        returnedToCardList = true
    }

    func leftCardList() {
        returnedToCardList = false
        automaticTip = nil
    }

    /// Keeps an automatic tip on screen; a paywall should survive switching apps.
    func endForegroundSession() {
        returnedToCardList = false
        suppressedThisSession = false
    }

    func nextPrompt(version: String, canPresent: Bool, tipsEnabled: Bool = true) -> Prompt? {
        guard canPresent, !suppressedThisSession, automaticTip == nil else { return nil }
        if tipsEnabled, let pendingTip, storage.bool(forKey: Key.tipDetailsSeen),
           returnedToCardList || resumedTip {
            return .tip(pendingTip)
        }
        guard returnedToCardList, !version.isEmpty, copyDays.count >= 3,
              !reviewedVersions.contains(version) else { return nil }
        return .review
    }

    @discardableResult
    func claim(_ prompt: Prompt, version: String, hasPurchasedTip: Bool? = nil) -> Bool {
        guard nextPrompt(version: version, canPresent: true, tipsEnabled: prompt != .review) == prompt else { return false }
        switch prompt {
        case .tip(let source):
            guard let hasPurchasedTip else {
                suppressedThisSession = true
                return false
            }
            // Consumed before presenting: SwiftUI may tear the paywall down without onDismiss.
            consumeTip()
            if hasPurchasedTip {
                returnedToCardList = false
                return false
            }
            suppressedThisSession = true
            automaticTip = AutomaticTip(source: source)
        case .review:
            suppressedThisSession = true
            reviewedVersions.append(version)
            storage.set(reviewedVersions, forKey: Key.reviewedVersions)
        }
        return true
    }

    func dismissAutomaticTip(_ attempt: AutomaticTip) {
        guard automaticTip == attempt else { return }
        automaticTip = nil
    }

    private func consumeTip() {
        pendingTip = nil
        storage.set("consumed", forKey: Key.tip)
        storage.removeObject(forKey: Key.tipDetailsSeen)
        storage.removeObject(forKey: Key.tipCardID)
    }

    func recordTipPresented() {
        suppressedThisSession = true
    }

    func recordShare() {
        suppressedThisSession = true
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
}

extension EnvironmentValues {
    @Entry var supportPromptPolicy: SupportPromptPolicy?
}
