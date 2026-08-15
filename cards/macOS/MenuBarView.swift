//
//  MenuBarView.swift
//  cards
//
//  Menu bar extra view for quick card access on macOS
//

#if os(macOS)
import AppKit
import SinghDevKit
import SwiftUI

enum MenuBarContentState: Equatable {
    case unavailable
    case empty
    case cards

    init(hasActiveCards: Bool, didLoadFail: Bool) {
        if hasActiveCards {
            self = .cards
        } else if didLoadFail {
            self = .unavailable
        } else {
            self = .empty
        }
    }
}

/// Window-style MenuBarExtra content is retained across opens. Observe its panel
/// so the card cache refreshes every time and sensitive access follows app focus.
private struct MenuBarPanelObserver: NSViewRepresentable {
    var onAppear: () -> Void
    var onDisappear: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = PanelObserverView()
        view.onAppear = onAppear
        view.onDisappear = onDisappear
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? PanelObserverView else { return }
        view.onAppear = onAppear
        view.onDisappear = onDisappear
    }

    private final class PanelObserverView: NSView {
        var onAppear: (() -> Void)?
        var onDisappear: (() -> Void)?
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeObservers()
            guard let window else { return }

            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onAppear?()
            })
            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onDisappear?()
            })

            if window.isKeyWindow {
                onAppear?()
            }
        }

        deinit {
            removeObservers()
        }

        private func removeObservers() {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
        }
    }
}

struct MenuBarView: View {
    var cardStore: CardDataStore
    @EnvironmentObject private var authenticationSession: AuthenticationSession
    @Environment(\.openWindow) private var openWindow
    @AppStorage("keepInMenuBar") private var keepInMenuBar = false
    @State private var didCardLoadFail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch contentState {
            case .unavailable:
                unavailableStateView
            case .empty:
                emptyStateView
            case .cards:
                cardListView
            }

            if let message = authenticationSession.authenticationMessage {
                Divider()
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }

            Divider()
            openHolderButton

            if keepInMenuBar {
                Divider()
                quitButton
            }
        }
        .frame(width: 320)
        .background {
            MenuBarPanelObserver(
                onAppear: refreshCards,
                onDisappear: handlePanelDisappear
            )
        }
        .onAppear {
            MainWindowCoordinator.register(openWindow: openWindow)
            refreshCards()
        }
        .sdkScreen(AppAnalyticsScreen.menuBar)
    }

    private var contentState: MenuBarContentState {
        MenuBarContentState(
            hasActiveCards: !allCards.isEmpty,
            didLoadFail: didCardLoadFail
        )
    }

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
            Button("Try Again", action: refreshCards)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
    }

    private var cardListView: some View {
        let cards = allCards
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(cards) { card in
                    MenuBarCardRow(
                        card: card,
                        isSensitiveAccessFresh: authenticationSession.isSensitiveAccessFresh,
                        isAuthenticating: authenticationSession.isAuthenticating,
                        authenticate: authenticateForSecurityCode
                    )
                    if card.id != cards.last?.id {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
        .frame(height: min(CGFloat(cards.count) * 58, 400))
    }

    private var openHolderButton: some View {
        Button {
            MainWindowCoordinator.register(openWindow: openWindow)
            MainWindowCoordinator.open()
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

    private var allCards: [CardData] {
        CardType.allCases.flatMap { cardStore.cardsByType[$0] ?? [] }
    }

    private func refreshCards() {
        didCardLoadFail = !cardStore.loadCards()
    }

    private func authenticateForSecurityCode() {
        NSApp.activate(ignoringOtherApps: true)
        authenticationSession.authenticateForSensitiveAccess(
            reason: "Authenticate to view this card's security code."
        )
    }

    private func handlePanelDisappear() {
        // Local Authentication can temporarily dismiss this panel. Preserve an
        // in-flight request, then revoke access when the app truly deactivates.
        Task { @MainActor in
            await Task.yield()
            guard !authenticationSession.isAuthenticating, !NSApp.isActive else { return }
            authenticationSession.didEnterBackground()
        }
    }
}

struct MenuBarCardRow: View {
    let card: CardData
    let isSensitiveAccessFresh: Bool
    let isAuthenticating: Bool
    let authenticate: () -> Void
    @State private var copiedField: String?
    @State private var isExpanded = false

    private let iconWidth: CGFloat = 20
    private let labelWidth: CGFloat = 70

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    networkImage
                        .frame(width: 36, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(cardDisplayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(card.number.maskedCardNumber())
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    if !card.expiration.isEmpty {
                        copyableDetailRow(
                            icon: "calendar",
                            label: "Expires",
                            displayValue: card.expiration,
                            copyValue: card.expiration,
                            field: "exp"
                        )
                    }

                    if !card.cvv.isEmpty {
                        copyableDetailRow(
                            icon: "lock.fill",
                            label: "CVV",
                            displayValue: isSensitiveAccessFresh ? card.cvv : "•••",
                            copyValue: card.cvv,
                            field: "cvv",
                            isSensitive: true
                        )
                    }

                    if !card.name.isEmpty {
                        copyableDetailRow(
                            icon: "person.fill",
                            label: "Name",
                            displayValue: card.name,
                            copyValue: card.name,
                            field: "name"
                        )
                    }
                }
                .padding(.horizontal, 12)
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

    private func copyableDetailRow(
        icon: String,
        label: String,
        displayValue: String,
        copyValue: String,
        field: String,
        isSensitive: Bool = false
    ) -> some View {
        Button {
            if isSensitive && !isSensitiveAccessFresh {
                authenticate()
            } else {
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
                    Label("Copied!", systemImage: "checkmark")
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
        .disabled(isSensitive && !isSensitiveAccessFresh && isAuthenticating)
    }

    private var cardDisplayName: String {
        if !card.description.isEmpty {
            return card.description
        }
        if !card.name.isEmpty {
            return card.name
        }
        return card.type.rawValue
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
