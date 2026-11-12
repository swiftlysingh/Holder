import SinghDevKit

enum AppAnalyticsEvent: AnalyticsEvent {
    enum SaveOperation: String, Sendable {
        case create
        case update
    }

    enum InputMethod: String, Sendable {
        case manual
        case scanner
    }

    enum CardLocation: String, Sendable {
        case active
        case archived
    }

    enum CardAddSource: String, Sendable {
        case home
        case onboarding
    }

    enum OnboardingOutcome: String, Sendable {
        case scanner
        case manual
        case skipped
    }

    case cardAddStarted(source: CardAddSource)
    case cardSaveCompleted(
        operation: SaveOperation,
        inputMethod: InputMethod
    )
    case cardSaveFailed(
        operation: SaveOperation,
        inputMethod: InputMethod
    )
    case cardDeleted(location: CardLocation)
    case cardDeleteFailed(location: CardLocation)
    case cardArchived
    case cardArchiveFailed
    case cardUnarchived
    case cardUnarchiveFailed
    case cardScanStarted(engine: String)
    case cardScanCompleted(
        engine: String,
        panSuccess: Bool,
        expirySuccess: Bool,
        holderSuccess: Bool,
        timeToPanMs: Int?,
        timeToCompleteMs: Int,
        rescan: Bool
    )
    case cardScanEnded(CardScanEndMetrics)
    case cardScanRetryableFailure(CardScanRetryMetrics)
    case cardOpenedFromWidget
    case onboardingShown(audience: HolderOnboardingAudience)
    case onboardingCompleted(
        audience: HolderOnboardingAudience,
        outcome: OnboardingOutcome
    )
    case onboardingReplayRequested

    var name: String {
        switch self {
        case .cardAddStarted:
            "card_add_started"
        case .cardSaveCompleted:
            "card_save_completed"
        case .cardSaveFailed:
            "card_save_failed"
        case .cardDeleted:
            "card_deleted"
        case .cardDeleteFailed:
            "card_delete_failed"
        case .cardArchived:
            "card_archived"
        case .cardArchiveFailed:
            "card_archive_failed"
        case .cardUnarchived:
            "card_unarchived"
        case .cardUnarchiveFailed:
            "card_unarchive_failed"
        case .cardScanStarted:
            "card_scan_started"
        case .cardScanCompleted:
            "card_scan_completed"
        case .cardScanEnded:
            "card_scan_ended"
        case .cardScanRetryableFailure:
            "card_scan_retryable_failure"
        case .cardOpenedFromWidget:
            "card_opened_from_widget"
        case .onboardingShown:
            "onboarding_shown"
        case .onboardingCompleted:
            "onboarding_completed"
        case .onboardingReplayRequested:
            "onboarding_replay_requested"
        }
    }

    var properties: AnalyticsProperties {
        switch self {
        case .cardSaveCompleted(let operation, let inputMethod),
             .cardSaveFailed(let operation, let inputMethod):
            return [
                "operation": .string(operation.rawValue),
                "input_method": .string(inputMethod.rawValue)
            ]
        case .cardDeleted(let location),
             .cardDeleteFailed(let location):
            return ["location": .string(location.rawValue)]
        case .cardScanStarted(let engine):
            return ["engine": .string(engine)]
        case .cardScanRetryableFailure(let metrics):
            return [
                "engine": .string(metrics.engine),
                "reason": .string("verification_conflict"),
                "elapsed_ms": .int(metrics.elapsedMs),
                "had_candidate": .bool(metrics.hadCandidate),
                "is_rescan": .bool(metrics.isRescan),
                "attempt_number": .int(metrics.attemptNumber)
            ]
        case .cardScanEnded(let metrics):
            var properties: AnalyticsProperties = [
                "engine": .string(metrics.engine),
                "outcome": .string(metrics.outcome.rawValue),
                "reason": .string(metrics.reason),
                "elapsed_ms": .int(metrics.elapsedMs),
                "had_candidate": .bool(metrics.hadCandidate),
                "torch_on": .bool(metrics.torchOn),
                "is_rescan": .bool(metrics.isRescan),
                "attempt_number": .int(metrics.attemptNumber)
            ]
            if let timeToPANMs = metrics.timeToPANMs {
                properties["time_to_pan_ms"] = .int(timeToPANMs)
            }
            return properties
        case .cardScanCompleted(
            let engine,
            let panSuccess,
            let expirySuccess,
            let holderSuccess,
            let timeToPanMs,
            let timeToCompleteMs,
            let rescan
        ):
            var properties: AnalyticsProperties = [
                "engine": .string(engine),
                "pan_success": .bool(panSuccess),
                "expiry_success": .bool(expirySuccess),
                "holder_success": .bool(holderSuccess),
                "time_to_complete_ms": .int(timeToCompleteMs),
                "rescan": .bool(rescan)
            ]
            if let timeToPanMs {
                properties["time_to_pan_ms"] = .int(timeToPanMs)
            }
            return properties
        case .cardAddStarted(let source):
            return ["source": .string(source.rawValue)]
        case .onboardingShown(let audience):
            return ["audience": .string(audience.rawValue)]
        case .onboardingCompleted(let audience, let outcome):
            return [
                "audience": .string(audience.rawValue),
                "outcome": .string(outcome.rawValue)
            ]
        case .onboardingReplayRequested,
             .cardArchived,
             .cardArchiveFailed,
             .cardUnarchived,
             .cardUnarchiveFailed,
             .cardOpenedFromWidget:
            return [:]
        }
    }

    var crashContext: AnalyticsCrashContext {
        switch self {
        case .cardSaveCompleted, .cardSaveFailed:
            .breadcrumb(including: ["operation", "input_method"])
        case .cardDeleted, .cardDeleteFailed:
            .breadcrumb(including: ["location"])
        case .cardAddStarted:
            .breadcrumb(including: ["source"])
        case .onboardingShown:
            .breadcrumb(including: ["audience"])
        case .onboardingCompleted:
            .breadcrumb(including: ["audience", "outcome"])
        case .onboardingReplayRequested,
             .cardArchived,
             .cardArchiveFailed,
             .cardUnarchived,
             .cardUnarchiveFailed,
             .cardScanStarted,
             .cardScanCompleted,
             .cardScanEnded,
             .cardScanRetryableFailure,
             .cardOpenedFromWidget:
            .breadcrumb()
        }
    }
}
