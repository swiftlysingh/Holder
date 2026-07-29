import SinghDevKit

enum AppAnalyticsEvent: AnalyticsEvent {
    enum CardCategory: String, Sendable {
        case creditCard = "credit_card"
        case debitCard = "debit_card"
        case otherCard = "other_card"

        init(_ cardType: CardType) {
            switch cardType {
            case .creditCard:
                self = .creditCard
            case .debitCard:
                self = .debitCard
            case .otherCard:
                self = .otherCard
            }
        }
    }

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

    case cardAddStarted(cardCategory: CardCategory)
    case cardSaveCompleted(
        operation: SaveOperation,
        cardCategory: CardCategory,
        inputMethod: InputMethod
    )
    case cardSaveFailed(
        operation: SaveOperation,
        cardCategory: CardCategory,
        inputMethod: InputMethod
    )
    case cardDeleted(cardCategory: CardCategory, location: CardLocation)
    case cardDeleteFailed(cardCategory: CardCategory, location: CardLocation)
    case cardArchived(cardCategory: CardCategory)
    case cardArchiveFailed(cardCategory: CardCategory)
    case cardUnarchived(cardCategory: CardCategory)
    case cardUnarchiveFailed(cardCategory: CardCategory)
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
        case .cardAddStarted(let cardCategory),
             .cardArchived(let cardCategory),
             .cardArchiveFailed(let cardCategory),
             .cardUnarchived(let cardCategory),
             .cardUnarchiveFailed(let cardCategory):
            cardProperties(cardCategory)
        case .cardSaveCompleted(let operation, let cardCategory, let inputMethod),
             .cardSaveFailed(let operation, let cardCategory, let inputMethod):
            cardProperties(cardCategory).merging([
                "operation": .string(operation.rawValue),
                "input_method": .string(inputMethod.rawValue)
            ]) { _, newValue in newValue }
        case .cardDeleted(let cardCategory, let location),
             .cardDeleteFailed(let cardCategory, let location):
            cardProperties(cardCategory).merging([
                "location": .string(location.rawValue)
            ]) { _, newValue in newValue }
        case .cardScanStarted,
             .cardScanCompleted,
             .cardScanPermissionDenied,
             .cardOpenedFromWidget:
            [:]
        }
    }

    private func cardProperties(_ cardCategory: CardCategory) -> AnalyticsProperties {
        ["card_category": .string(cardCategory.rawValue)]
    }
}
