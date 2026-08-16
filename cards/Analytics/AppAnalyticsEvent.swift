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
    case cardScanStarted
    case cardScanCompleted
    case cardScanPermissionDenied
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
        case .cardOpenedFromWidget:
            "card_opened_from_widget"
        }
    }

    var properties: AnalyticsProperties {
        switch self {
        case .cardSaveCompleted(let operation, let inputMethod),
             .cardSaveFailed(let operation, let inputMethod):
            [
                "operation": .string(operation.rawValue),
                "input_method": .string(inputMethod.rawValue)
            ]
        case .cardDeleted(let location),
             .cardDeleteFailed(let location):
            ["location": .string(location.rawValue)]
        case .cardAddStarted,
             .cardArchived,
             .cardArchiveFailed,
             .cardUnarchived,
             .cardUnarchiveFailed,
             .cardScanStarted,
             .cardScanCompleted,
             .cardScanPermissionDenied,
             .cardOpenedFromWidget:
            [:]
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
             .cardOpenedFromWidget:
            .breadcrumb()
        }
    }
}
