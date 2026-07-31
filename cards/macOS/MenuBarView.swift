//
//  MenuBarView.swift
//  cards
//
//  Menu bar extra view for quick card access on macOS
//

#if os(macOS)
import AppKit
import LocalAuthentication
import SinghDevKit
import SwiftUI

enum MenuBarContentState: Equatable {
    case locked
    case unavailable
    case empty
    case cards

    init(isAuthEnabled: Bool, isUnlocked: Bool, hasActiveCards: Bool, didLoadFail: Bool) {
        if isAuthEnabled && !isUnlocked {
            self = .locked
        } else if hasActiveCards {
            self = .cards
        } else if didLoadFail {
            self = .unavailable
        } else {
            self = .empty
        }
    }
}

@MainActor
final class MenuBarSession: ObservableObject {
    @Published private(set) var isUnlocked = false
    private var lockTask: Task<Void, Never>?
    private let sleeper: AsyncSleeper

    init(sleeper: AsyncSleeper = TaskAsyncSleeper()) {
        self.sleeper = sleeper
    }

    func unlock(for timeout: Duration) {
        lockTask?.cancel()
        isUnlocked = true
        let sleeper = self.sleeper
        lockTask = Task { [weak self, sleeper] in
            do {
                try await sleeper.sleep(for: timeout)
            } catch {
                // Includes cancellation and injected sleeper failures.
                return
            }
            guard !Task.isCancelled else { return }
            self?.lock()
        }
    }

    func lock() {
        lockTask?.cancel()
        lockTask = nil
        isUnlocked = false
    }
}

/// Window-style MenuBarExtra content is retained across opens. Observe the hosting
/// panel becoming key so card data refreshes on every open, not only the first appear.
private struct MenuBarPanelAppearObserver: NSViewRepresentable {
    var onPanelAppear: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = PanelAppearView()
        view.onPanelAppear = onPanelAppear
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? PanelAppearView)?.onPanelAppear = onPanelAppear
    }

    private final class PanelAppearView: NSView {
        var onPanelAppear: (() -> Void)?
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeObserver()
            guard let window else { return }

            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onPanelAppear?()
            }

            if window.isKeyWindow {
                onPanelAppear?()
            }
        }

        deinit {
            removeObserver()
        }

        private func removeObserver() {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
        }
    }
}

struct MenuBarView: View {
    var cardStore: CardDataStore
    @Environment(\.openWindow) private var openWindow
    // Same keys as UserSettings; @AppStorage on the view observes changes reliably
    // (UserSettings' @AppStorage properties do not publish via ObservableObject).
    @AppStorage("isAuthEnabled") private var isAuthEnabled = true
    @AppStorage("timeout") private var authTimeout = 10
    @AppStorage("keepInMenuBar") private var keepInMenuBar = false
    @StateObject private var session = MenuBarSession()
    @State private var authStatus: String?
    @State private var authContext: LAContext?
    @State private var didCardLoadFail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch contentState {
            case .locked:
                lockedStateView
            case .unavailable:
                unavailableStateView
            case .empty:
                emptyStateView
            case .cards:
                cardListView
            }

            Divider()

            openHolderButton

            // Show Quit button when running in menu bar-only mode
            if keepInMenuBar {
                Divider()
                quitButton
            }
        }
        .frame(width: 320)
        .background {
            MenuBarPanelAppearObserver {
                refreshCards()
            }
        }
        .onAppear {
            // Keep a live OpenWindowAction for Dock reopen after the main window is closed.
            MainWindowCoordinator.register(openWindow: openWindow)
            refreshCards()
        }
        // Successful unlock is bounded only by MenuBarSession timeout (and settings
        // changes below). Do not lock on disappear: LA presentation dismisses the
        // panel and would race the unlock callback.
        .onChange(of: isAuthEnabled) { _, isEnabled in
            cancelAuthentication()
            session.lock()
            authStatus = nil
            if !isEnabled {
                refreshCards()
            }
        }
        .onChange(of: authTimeout) {
            if isAuthEnabled && session.isUnlocked {
                session.unlock(for: .seconds(authTimeout))
            }
        }
        .sdkScreen(AppAnalyticsScreen.menuBar)
    }

    private var contentState: MenuBarContentState {
        MenuBarContentState(
            isAuthEnabled: isAuthEnabled,
            isUnlocked: session.isUnlocked,
            hasActiveCards: !allCards.isEmpty,
            didLoadFail: didCardLoadFail
        )
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "creditcard")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No cards saved")
                .foregroundStyle(.secondary)
            Text("Open Holder to add cards")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var unavailableStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.icloud")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Cards Unavailable")
                .font(.headline)
            Text("Holder couldn’t refresh your cards. Your saved data has not been changed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                refreshCards()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
    }

    private var lockedStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Vault Locked")
                .font(.headline)

            Text("Unlock with Touch ID or your Mac password")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                authenticate()
            } label: {
                HStack {
                    Image(systemName: "lock.open.fill")
                    Text("Unlock Vault")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let status = authStatus {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
    }

    private var cardListView: some View {
        let cards = allCards
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(cards) { card in
                    MenuBarCardRow(card: card, isAuthenticated: contentState != .locked)
                    if card.id != cards.last?.id {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
        // MenuBarExtra windows do not always recompute their intrinsic height when
        // the card store refreshes after opening, so reserve the collapsed row height.
        .frame(height: min(CGFloat(cards.count) * 58, 400))
    }

    private var openHolderButton: some View {
        Button {
            openMainApp()
        } label: {
            HStack {
                Image(systemName: "rectangle.stack")
                Text("Open Holder")
                Spacer()
                Text("⌘O")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("o", modifiers: .command)
    }

    private var quitButton: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            HStack {
                Image(systemName: "power")
                Text("Quit Holder")
                Spacer()
                Text("⌘Q")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q", modifiers: .command)
    }

    // MARK: - Helpers

    private func refreshCards() {
        didCardLoadFail = !cardStore.loadCards()
    }

    private var allCards: [CardData] {
        CardType.allCases.flatMap { cardStore.cardsByType[$0] ?? [] }
    }

    private func openMainApp() {
        // Same path as Dock reopen: focus/deminiaturize the registered main window, else open singleton scene.
        MainWindowCoordinator.register(openWindow: openWindow)
        MainWindowCoordinator.open()
    }

    private func authenticate() {
        cancelAuthentication()
        authStatus = nil
        NSApp.activate(ignoringOtherApps: true)

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error {
                print("Menu bar unlock unavailable: \(error.localizedDescription) (\(error.domain) \(error.code))")
            } else {
                print("Menu bar unlock unavailable: device owner authentication cannot be evaluated")
            }
            session.lock()
            authStatus = "Unlock isn’t available on this Mac. Open Holder to manage your cards."
            return
        }

        authContext = context
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock your Holder vault"
        ) { success, _ in
            Task { @MainActor in
                guard authContext === context else { return }
                authContext = nil

                if success && isAuthEnabled {
                    session.unlock(for: .seconds(authTimeout))
                    authStatus = nil
                } else if isAuthEnabled {
                    session.lock()
                    authStatus = "Your vault is still locked. Try again when you're ready."
                }
            }
        }
    }

    private func cancelAuthentication() {
        authContext?.invalidate()
        authContext = nil
    }
}

struct MenuBarCardRow: View {
    let card: CardData
    let isAuthenticated: Bool
    @State private var copiedField: String?
    @State private var isExpanded = false

    private let iconWidth: CGFloat = 20
    private let labelWidth: CGFloat = 70

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card header - tap to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Network logo or fallback icon
                    networkImage
                        .frame(width: 36, height: 24)

                    // Card name and masked number
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cardDisplayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(maskedNumber)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    // Card Number
                    if !card.number.isEmpty {
                        copyableDetailRow(
                            icon: "number",
                            label: "Number",
                            displayValue: isAuthenticated ? formatCardNumber(card.number) : "•••• •••• •••• ••••",
                            copyValue: card.number,
                            field: "number",
                            isSensitive: true
                        )
                    }

                    // Expiration
                    if !card.expiration.isEmpty {
                        copyableDetailRow(
                            icon: "calendar",
                            label: "Expires",
                            displayValue: isAuthenticated ? card.expiration : "••/••",
                            copyValue: card.expiration,
                            field: "exp",
                            isSensitive: true
                        )
                    }

                    // CVV
                    if !card.cvv.isEmpty {
                        copyableDetailRow(
                            icon: "lock.fill",
                            label: "CVV",
                            displayValue: "•••",
                            copyValue: card.cvv,
                            field: "cvv",
                            isSensitive: true
                        )
                    }

                    // Name on card (not sensitive)
                    if !card.name.isEmpty {
                        copyableDetailRow(
                            icon: "person.fill",
                            label: "Name",
                            displayValue: card.name,
                            copyValue: card.name,
                            field: "name",
                            isSensitive: false
                        )
                    }
                }
                .padding(.leading, 60)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
                .background(Color.primary.opacity(0.03))
            }
        }
    }

    @ViewBuilder
    private var networkImage: some View {
        if card.type != .otherCard && card.network != .other {
            Image(card.network.rawValue)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func copyableDetailRow(icon: String, label: String, displayValue: String, copyValue: String, field: String, isSensitive: Bool) -> some View {
        Button {
            // Only allow copy if authenticated or field is not sensitive
            if isAuthenticated || !isSensitive {
                copyToClipboard(copyValue, field: field)
            }
        } label: {
            HStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(width: iconWidth, alignment: .leading)

                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: labelWidth, alignment: .leading)

                Spacer()

                if copiedField == field {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Copied!")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green)
                } else {
                    Text(displayValue)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSensitive && !isAuthenticated)
    }

    private var cardDisplayName: String {
        if !card.description.isEmpty {
            return card.description
        } else if !card.name.isEmpty {
            return card.name
        } else {
            return card.type.rawValue
        }
    }

    private var maskedNumber: String {
        let cleanNumber = card.number.replacingOccurrences(of: " ", with: "")
        if cleanNumber.count >= 4 {
            return "**** " + String(cleanNumber.suffix(4))
        } else if !cleanNumber.isEmpty {
            // For short numbers, mask all but show count
            return String(repeating: "*", count: cleanNumber.count)
        }
        return "No number"
    }

    private func formatCardNumber(_ number: String) -> String {
        let clean = number.replacingOccurrences(of: " ", with: "")
        var result = ""
        for (index, char) in clean.enumerated() {
            if index > 0 && index % 4 == 0 {
                result += " "
            }
            result.append(char)
        }
        return result
    }

    private func copyToClipboard(_ value: String, field: String) {
        PasteboardService.copy(value)
        copiedField = field
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedField == field {
                copiedField = nil
            }
        }
    }
}
#endif
