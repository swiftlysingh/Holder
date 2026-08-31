import SinghDevKit

enum AppAnalyticsScreen: String, AnalyticsScreen {
    case home
    case cardDetails = "card_details"
    case cardEditor = "card_editor"
    case archivedCards = "archived_cards"
    case settings
    case onboardingWelcome = "onboarding_welcome"
    case onboardingGetStarted = "onboarding_get_started"
    case cardScanner = "card_scanner"
    case menuBar = "menu_bar"

    var name: String { rawValue }

    var properties: AnalyticsProperties { [:] }

    var crashContext: AnalyticsCrashContext { .breadcrumb() }
}
