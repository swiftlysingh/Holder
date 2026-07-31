//
//  credit_cardApp.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import Foundation
import SwiftUI
import TipKit
import WhatsNewKit
import SinghDevKit

#if os(macOS)
import AppKit
#endif

/// Stable scene id for the main SwiftUI window; used with `openWindow` on macOS.
enum MainWindowScene {
    static let id = "main"
}

#if os(macOS)
/// Shared open path for Menu Bar "Open Holder" and Dock reopen.
/// Registers the exact main `NSWindow` (never Settings / `canBecomeMain` search) plus
/// `OpenWindowAction` so AppDelegate can recreate the singleton scene without SwiftUI environment.
@MainActor
enum MainWindowCoordinator {
    private static weak var mainWindow: NSWindow?
    private static var openWindow: OpenWindowAction?

    static func register(window: NSWindow) {
        mainWindow = window
    }

    /// Clears the registered window only when `window` is the currently tracked host,
    /// so an obsolete accessor cannot unregister a newer main window.
    static func unregister(window: NSWindow) {
        guard mainWindow === window else { return }
        mainWindow = nil
    }

    static func register(openWindow: OpenWindowAction) {
        self.openWindow = openWindow
    }

    /// Restore Dock presence, focus/deminiaturize the registered main window, or open the singleton scene.
    /// Returns false when SwiftUI has not registered either route yet so AppKit can use its default reopen behavior.
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
}

/// Bridge: SwiftUI `openWindow` is only in the environment; AppDelegate needs a stored action for Dock reopen.
/// Also captures the exact main `NSWindow` hosting this content (not Settings).
private struct MainWindowRegistrar: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .background(MainWindowAccessor())
            .onAppear {
                MainWindowCoordinator.register(openWindow: openWindow)
            }
    }
}

/// Bridge: AppKit window identity is not available from SwiftUI; bind the host `NSWindow` once attached.
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
        // If "Keep in Menu Bar" is enabled, don't quit when window closes
        if UserSettings.shared.keepInMenuBar {
            // Hide from dock but keep running in menu bar
            NSApp.setActivationPolicy(.accessory)
            return false
        }
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        // Ignore hasVisibleWindows: Settings-only still reports true, but Dock must restore main (P2).
        return !MainWindowCoordinator.open()
    }
}
#endif

@main
struct CreditCard: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    /// Shared card data store for menu bar access on macOS
    @State private var cardDataStore = CardDataStore()
    private let sdkBootstrapper: SDKBootstrapper

    init() {
        let sdkBootstrapper = SDKBootstrapper()
        self.sdkBootstrapper = sdkBootstrapper

        Task {
            await sdkBootstrapper.configure(with: AppSecrets.load())
        }
    }

    var body: some Scene {
        #if os(macOS)
        // Single-instance main scene: openWindow focuses/recreates this window rather than spawning duplicates.
        Window("Holder", id: MainWindowScene.id) {
            rootContent
                .background(MainWindowRegistrar())
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
        HomeView(cardDataStore: cardDataStore)
            .task {
                try? Tips.configure([
                    .displayFrequency(.immediate),
                    .datastoreLocation(.applicationDefault)
                ])
            }
            .environment(
                \.whatsNew,
                 WhatsNewEnvironment(
                    versionStore: UserDefaultsWhatsNewVersionStore(),
                    whatsNewCollection: self
                 )
            )
            .withSDK(.shared)
            .showOnboardingIfNeeded(features: [.init(image: Image(systemName: "lock.shield"),
                                                     title: "Secure Storage",
                                                     content: "Keep your card details safe with state-of-the-art encryption."),
                                               .init(image: Image(systemName: "faceid"),
                                                     title: "Biometric Authentication",
                                                     content: "Access your cards securely using Face ID or Touch ID."),
                                               .init(image: Image(systemName: "square.and.arrow.up"),
                                                     title: "Easily Shareable",
                                                     content: "Quickly and securely share card details with trusted contacts."),
                                               .init(image: Image(systemName: "hand.raised.slash"),
                                                     title: "Privacy First, Open Source",
                                                     content: "Your data stays private and secure, and the app's code is open-source for transparency.")]
            )
    }

    #if os(macOS)
    var menuBarScene: some Scene {
        MenuBarExtra("Holder", systemImage: "creditcard.fill") {
            MenuBarView(cardStore: cardDataStore)
                .withSDK(.shared)
        }
        .menuBarExtraStyle(.window)
    }

    var settingsScene: some Scene {
        SwiftUI.Settings {
            SettingsView(configuration: SettingsViewModel())
                .sdkScreen(AppAnalyticsScreen.settings)
                .withSDK(.shared)
                .presentationSizing(.fitted)
                .frame(minWidth: 620, minHeight: 480)
        }
    }
    #endif
}

private actor SDKBootstrapper {
    private enum State {
        case idle
        case configuring
        case configured
        case failed
    }

    private var state: State = .idle

    func configure(with appSecrets: AppSecrets) async {
        switch state {
        case .idle, .failed:
            state = .configuring
        case .configuring, .configured:
            return
        }

        do {
            try await SinghDevKit.shared.configure(
                SDKConfiguration(
                    analytics: appSecrets.analyticsConfiguration,
                    payments: appSecrets.paymentsConfiguration
                )
            )
            state = .configured
        } catch {
            state = .failed
            print("Warning: Failed to configure SinghDevKit: \(error.localizedDescription)")
        }
    }
}

struct AppSecrets: Sendable {
    let postHogProjectToken: String?
    let postHogHost: URL
    let revenueCatAPIKey: String?

    var analyticsConfiguration: AnalyticsConfiguration {
        postHogProjectToken.map {
            .postHog(projectToken: $0, host: postHogHost)
        } ?? .disabled
    }

    var paymentsConfiguration: PaymentsConfiguration {
        revenueCatAPIKey.map { .revenueCat(apiKey: $0) } ?? .disabled
    }

    static func load() -> Self {
        let secrets: [String: Any]
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dictionary = NSDictionary(contentsOfFile: path) as? [String: Any] {
            secrets = dictionary
        } else {
            print("Warning: Missing Secrets.plist - analytics disabled")
            secrets = [:]
        }

        return load(
            from: secrets,
            appConfiguration: Bundle.main.infoDictionary ?? [:]
        )
    }

    static func load(
        from secrets: [String: Any],
        appConfiguration: [String: Any]
    ) -> Self {
        let projectToken = nonEmptyString(from: secrets["PostHogProjectToken"])
        if projectToken == nil {
            print("Warning: Missing PostHogProjectToken in Secrets.plist - analytics disabled")
        }

        let revenueCatAPIKey = nonEmptyString(from: appConfiguration["RevenueCatAPIKey"])
        if revenueCatAPIKey == nil {
            print("Warning: Missing RevenueCatAPIKey in Info.plist - payments disabled")
        }

        let host = nonEmptyString(from: secrets["PostHogHost"])
            .flatMap(URL.init(string:))
            ?? URL(string: "https://us.i.posthog.com")!

        return Self(
            postHogProjectToken: projectToken,
            postHogHost: host,
            revenueCatAPIKey: revenueCatAPIKey
        )
    }

    private static func nonEmptyString(from value: Any?) -> String? {
        guard let string = value as? String else { return nil }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension CreditCard: WhatsNewCollectionProvider {
  var primaryAction: WhatsNew.PrimaryAction {
	#if os(iOS)
	WhatsNew.PrimaryAction(
	  title: "Dive In 🚀",
	  backgroundColor: .accentColor,
	  foregroundColor: .white,
	  hapticFeedback: .notification(.success),
	  onDismiss: {
		print("Ready to explore the new features!")
	  }
	)
	#else
	WhatsNew.PrimaryAction(
	  title: "Dive In 🚀",
	  backgroundColor: .accentColor,
	  foregroundColor: .white,
	  onDismiss: {
		print("Ready to explore the new features!")
	  }
	)
	#endif
  }

  var title: WhatsNew.Title {
	return WhatsNew.Title(text: "Discover What's New in Holder!")
  }

  var bugFixFeature: WhatsNew.Feature {
	WhatsNew.Feature(
	  image: .init(systemName: "ant.fill"),
	  title: "Bug Squashing Party 🐜🔨",
	  subtitle: "We threw a party for bugs, and none made it out alive. Enjoy the smoother experience!"
	)
  }

  var whatsNewCollection: WhatsNewCollection {
	return [
	  WhatsNew(
		version: "1.6",
		title: title,
		features: [
		  WhatsNew.Feature(
			image: .init(systemName: "camera.fill"),
			title: "Add & Store All Your Cards",
			subtitle: "Easily save gift cards, ID cards, and more with images for quick access!"
		  ),
		  bugFixFeature
		],
		primaryAction: primaryAction
	  ),

	  WhatsNew(
		version: "1.5",
		title: title,
		features: [
		  WhatsNew.Feature(
			image: .init(systemName: "gear.badge.checkmark"),
			title: "New and improved settings",
			subtitle: "Configurations are easier and beautiful than ever!"
		  ),
		  bugFixFeature
		],
		primaryAction: primaryAction
	  ),
	  WhatsNew(
		version: "1.4",
		title: title,
		features: [
		  WhatsNew.Feature(
			image: .init(systemName: "creditcard.and.123"),
			title: "Network Images are here!",
			subtitle: "Now, it's easy to identify cards using there network!"
		  ),
		  bugFixFeature
		],
		primaryAction: primaryAction
	  ),
	  WhatsNew(
		version: "1.3",
		title: title,
		features: [
		  WhatsNew.Feature(
			image: .init(systemName: "square.and.arrow.up.fill"),
			title: "Sharing is here",
			subtitle: "Effortlessly share your cards with friends and family"
		  ),
		  WhatsNew.Feature(
			image: .init(systemName: "ipad.sizes"),
			title: "Now Authentication is Optional",
			subtitle: "For the daring, enjoy a more smooth experience with no Authentication"
		  ),
		  bugFixFeature
		],
		primaryAction: primaryAction
	  ),
	  WhatsNew(
		version: "1.2",
		title: title,
		features: [
		  WhatsNew.Feature(
			image: .init(systemName: "cloud"),
			title: "iCloud Sync Is Here!",
			subtitle: "Effortlessly keep your cards in sync across all devices."
		  ),
		  WhatsNew.Feature(
			image: .init(systemName: "ipad.sizes"),
			title: "Optimized for iPad",
			subtitle: "Enjoy a seamless, multitasking-friendly UI, now with split view."
		  ),
		  bugFixFeature
		],
		primaryAction: primaryAction
	  ),
	  WhatsNew(
		version: "1.1",
		title: title,
		features: [
		  WhatsNew.Feature(
			image: .init(systemName: "camera.on.rectangle"),
			title: "Snap & Add Cards 📸",
			subtitle: "Adding your cards is now a snap away! Just point your camera, and voilà, securely stored."
		  ),
		  WhatsNew.Feature(
			image: .init(systemName: "star.fill"),
			title: "Rate Us With a Tap 💫",
			subtitle: "Loving Holder? Tap to rate us! Your feedback brings smiles and helps us grow."
		  ),
		  bugFixFeature
		],
		primaryAction: primaryAction
	  )
	]

  }
}
