//
//  MenuBarView.swift
//  cards
//
//  Menu bar extra view for quick card access on macOS
//

#if os(macOS)
import SwiftUI
import AppKit
import LocalAuthentication

struct MenuBarView: View {
    var cardStore: CardDataStore
    @State private var isAuthenticated = false
    @State private var authError: String?

    // Check if auth is required based on settings
    private var requiresAuth: Bool {
        UserSettings.shared.isAuthEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if allCards.isEmpty {
                emptyStateView
            } else if requiresAuth && !isAuthenticated {
                lockedStateView
            } else {
                cardListView
            }

            Divider()

            openHolderButton
        }
        .frame(width: 320)
        .onAppear {
            // Auto-authenticate if auth is disabled
            if !requiresAuth {
                isAuthenticated = true
            }
        }
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

    private var lockedStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Cards Locked")
                .font(.headline)

            Text("Authenticate to view your cards")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                authenticate()
            } label: {
                HStack {
                    Image(systemName: "touchid")
                    Text("Unlock with Touch ID")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let error = authError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
    }

    private var cardListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(allCards) { card in
                    MenuBarCardRow(card: card, isAuthenticated: isAuthenticated)
                    if card.id != allCards.last?.id {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
        .frame(maxHeight: 400)
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

    // MARK: - Helpers

    private var allCards: [CardData] {
        CardType.allCases.flatMap { cardStore.cardsByType[$0] ?? [] }
    }

    private func openMainApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to access your cards"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                Task { @MainActor in
                    if success {
                        isAuthenticated = true
                        authError = nil
                    } else {
                        authError = authenticationError?.localizedDescription ?? "Authentication failed"
                    }
                }
            }
        } else {
            // Fallback to password if biometrics unavailable
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                let reason = "Authenticate to access your cards"
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                    Task { @MainActor in
                        if success {
                            isAuthenticated = true
                            authError = nil
                        } else {
                            authError = authenticationError?.localizedDescription ?? "Authentication failed"
                        }
                    }
                }
            } else {
                authError = error?.localizedDescription ?? "Authentication not available"
            }
        }
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
        }
        return card.number.isEmpty ? "No number" : card.number
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
