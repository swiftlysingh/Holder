import Foundation
import SwiftUI
import TipKit
import SinghDevKit

#if os(macOS)
import AppKit
#endif

enum MainWindowScene {
    static let id = "main"
}

#if os(macOS)
@MainActor
enum MainWindowCoordinator {
    private static weak var mainWindow: NSWindow?
    private static weak var authenticationSession: AuthenticationSession?
    private static var openWindow: OpenWindowAction?
    private static var closeObserver: NSObjectProtocol?

    static func register(authenticationSession: AuthenticationSession) {
        self.authenticationSession = authenticationSession
    }

    static func register(window: NSWindow) {
        guard mainWindow !== window else { return }
        stopObservingMainWindowClose()
        mainWindow = window
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                MainWindowCoordinator.mainWindowDidClose(window: window)
            }
        }
    }

    static func unregister(window: NSWindow) {
        guard mainWindow === window else { return }
        stopObservingMainWindowClose()
        mainWindow = nil
    }

    private static func mainWindowDidClose(window: NSWindow) {
        guard mainWindow === window else { return }
        authenticationSession?.didEnterBackground()
        unregister(window: window)
    }

    static func register(openWindow: OpenWindowAction) {
        self.openWindow = openWindow
    }

    @discardableResult
    static func open() -> Bool {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let mainWindow {
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.makeKeyAndOrderFront(nil)
            return true
        }

        guard let openWindow else { return false }
        openWindow(id: MainWindowScene.id)
        return true
    }

    private static func stopObservingMainWindowClose() {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
            self.closeObserver = nil
        }
    }
}

private struct MainWindowRegistrar: View {
    let authenticationSession: AuthenticationSession
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .background(MainWindowAccessor())
            .onAppear {
                MainWindowCoordinator.register(authenticationSession: authenticationSession)
                MainWindowCoordinator.register(openWindow: openWindow)
            }
    }
}

private struct MainWindowAccessor: NSViewRepresentable {
    final class HostView: NSView {
        var onWindowChange: ((NSWindow?, NSWindow?) -> Void)?
        private weak var registeredWindow: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let previous = registeredWindow
            registeredWindow = window
            onWindowChange?(previous, window)
        }
    }

    func makeNSView(context: Context) -> HostView {
        let view = HostView()
        view.onWindowChange = { previous, window in
            if let previous {
                MainWindowCoordinator.unregister(window: previous)
            }
            if let window {
                MainWindowCoordinator.register(window: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: HostView, context: Context) {}
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        if UserSettings.shared.keepInMenuBar {
            NSApp.setActivationPolicy(.accessory)
            return false
        }
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        // Ignore hasVisibleWindows: Settings-only still reports true, but Dock must restore main.
        return !MainWindowCoordinator.open()
    }
}
#endif

@main
struct CreditCard: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("keepInMenuBar") private var keepInMenuBar = false
    #endif

    @State private var cardDataStore: CardDataStore
    @State private var sdk: SinghDevKit
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var authenticationSession = AuthenticationSession()
    @StateObject private var appFlow: HolderAppFlow
    private let privacyPolicyURL: URL?

    init() {
        let cardDataStore = CardDataStore()
        let appSecrets = AppSecrets.load()
        let settings = SettingsViewModel()
        let sdkConfiguration = SDKConfiguration(
            analytics: appSecrets.analyticsConfiguration,
            diagnostics: .metricKit(),
            observability: appSecrets.observabilityConfiguration,
            payments: appSecrets.paymentsConfiguration,
            settings: settings,
            onboarding: .default()
        )
        _cardDataStore = State(initialValue: cardDataStore)
        _homeViewModel = StateObject(
            wrappedValue: HomeViewModel(cardDataStore: cardDataStore)
        )
        self.privacyPolicyURL = settings.privacyPolicyURL
        _sdk = State(initialValue: SinghDevKit(configuration: sdkConfiguration))
        _appFlow = StateObject(wrappedValue: HolderAppFlow())
    }

    var body: some Scene {
        #if os(macOS)
        Window("Holder", id: MainWindowScene.id) {
            rootContent
                .background(MainWindowRegistrar(authenticationSession: authenticationSession))
        }
        menuBarScene
        settingsScene
        #else
        WindowGroup {
            rootContent
        }
        #endif
    }

    @ViewBuilder
    private var rootContent: some View {
        VaultProtectedView(session: authenticationSession) {
            HomeView(
                model: homeViewModel,
                appFlow: appFlow,
                privacyPolicyURL: privacyPolicyURL
            )
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
        }
        .environmentObject(authenticationSession)
        .withSDK(sdk)
    }

    #if os(macOS)
    var menuBarScene: some Scene {
        MenuBarExtra("Holder", systemImage: "creditcard.fill", isInserted: $keepInMenuBar) {
            MenuBarView(cardStore: cardDataStore)
                .environmentObject(authenticationSession)
                .withSDK(sdk)
        }
        .menuBarExtraStyle(.window)
    }

    var settingsScene: some Scene {
        SwiftUI.Settings {
            sdk.settingsView()
                .sdkScreen(AppAnalyticsScreen.settings)
                .environmentObject(authenticationSession)
                .environment(
                    \.holderOnboardingReplayAction,
                    HolderOnboardingReplayAction {
                        appFlow.requestOnboardingReplay()
                        MainWindowCoordinator.open()
                    }
                )
                .withSDK(sdk)
                .presentationSizing(.fitted)
                .frame(minWidth: 620, minHeight: 480)
        }
    }
    #endif
}

struct AppSecrets: Sendable {
    let postHogProjectToken: String?
    let postHogHost: URL
    let revenueCatAPIKey: String?
    let sentryDSN: String?

    var analyticsConfiguration: AnalyticsConfiguration {
        postHogProjectToken.map {
            .postHog(projectToken: $0, host: postHogHost)
        } ?? .disabled
    }

    var paymentsConfiguration: PaymentsConfiguration {
        revenueCatAPIKey.map { .revenueCat(apiKey: $0) } ?? .disabled
    }

    var observabilityConfiguration: ObservabilityConfiguration {
        sentryDSN.map {
            .sentry(
                dsn: $0,
                environment: Self.sentryEnvironment,
                release: Self.sentryRelease
            )
        } ?? .disabled
    }

    static var sentryEnvironment: String {
        #if DEBUG
        "debug"
        #elseif BETA
        "beta"
        #else
        "production"
        #endif
    }

    static var sentryRelease: String {
        "\(Bundle.main.bundleIdentifier ?? "com.swiftlysingh.cards")@\(Bundle.main.versionNumber)+\(Bundle.main.buildNumber)"
    }

    static func load() -> Self {
        load(from: Bundle.main.infoDictionary ?? [:])
    }

    static func load(from appConfiguration: [String: Any]) -> Self {
        let projectToken = nonEmptyString(from: appConfiguration["PostHogProjectToken"])
        if projectToken == nil {
            print("Warning: Missing PostHogProjectToken in Info.plist - analytics disabled")
        }

        let revenueCatAPIKey = nonEmptyString(from: appConfiguration["RevenueCatAPIKey"])
        if revenueCatAPIKey == nil {
            print("Warning: Missing RevenueCatAPIKey in Info.plist - payments disabled")
        }

        let sentryDSN = nonEmptyString(from: appConfiguration["SentryDSN"])
        if sentryDSN == nil {
            print("Warning: Missing SentryDSN in Info.plist - observability disabled")
        }

        let host = nonEmptyString(from: appConfiguration["PostHogHost"])
            .flatMap(URL.init(string:))
            ?? URL(string: "https://us.i.posthog.com")!

        return Self(
            postHogProjectToken: projectToken,
            postHogHost: host,
            revenueCatAPIKey: revenueCatAPIKey,
            sentryDSN: sentryDSN
        )
    }

    private static func nonEmptyString(from value: Any?) -> String? {
        guard let string = value as? String else { return nil }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
