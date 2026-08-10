import SinghDevKit

enum AppAnalyticsScreen: String, AnalyticsScreen {
    case home
    case cardDetails = "card_details"
    case cardEditor = "card_editor"
    case documentDetails = "document_details"
    case documentEditor = "document_editor"
    case archivedCards = "archived_cards"
    case settings
    case cardScanner = "card_scanner"
    case menuBar = "menu_bar"

    var name: String { rawValue }

    var properties: AnalyticsProperties { [:] }
}
