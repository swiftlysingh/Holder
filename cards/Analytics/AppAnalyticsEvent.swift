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

    case cardAddStarted
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
    case cardScanPermissionDenied(engine: String)
    case cardScanRescanRequested(engine: String)
    case cardOpenedFromWidget

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
        case .cardScanPermissionDenied:
            "card_scan_permission_denied"
        case .cardScanRescanRequested:
            "card_scan_rescan_requested"
        case .cardOpenedFromWidget:
            "card_opened_from_widget"
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
        case .cardScanStarted(let engine),
             .cardScanPermissionDenied(let engine),
             .cardScanRescanRequested(let engine):
            return ["engine": .string(engine)]
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
        case .cardAddStarted,
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
        case .cardAddStarted,
             .cardArchived,
             .cardArchiveFailed,
             .cardUnarchived,
             .cardUnarchiveFailed,
             .cardScanStarted,
             .cardScanCompleted,
             .cardScanPermissionDenied,
             .cardScanRescanRequested,
             .cardOpenedFromWidget:
            .breadcrumb()
        }
    }
}
