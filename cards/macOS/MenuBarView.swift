//
//  MenuBarView.swift
//  cards
//
//  Menu bar extra view for quick card access on macOS
//

#if os(macOS)
import SwiftUI
import AppKit

struct MenuBarView: View {
    var cardStore: CardDataStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if allCards.isEmpty {
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
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(allCards) { card in
                            MenuBarCardRow(card: card)
                            if card.id != allCards.last?.id {
                                Divider()
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Divider()

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
        .frame(width: 280)
    }

    private var allCards: [CardData] {
        CardType.allCases.flatMap { cardStore.cardsByType[$0] ?? [] }
    }

    private func openMainApp() {
        NSApp.activate(ignoringOtherApps: true)
        // Open or bring forward the main window
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

struct MenuBarCardRow: View {
    let card: CardData
    @State private var copiedField: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Card Name/Description
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(.secondary)
                Text(card.description.isEmpty ? card.name : card.description)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(card.type.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Masked Number with Copy Button
            HStack {
                Text(maskedNumber)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                copyButton(value: card.number, field: "number", label: "Copy")
            }

            // Quick copy buttons for other fields
            HStack(spacing: 8) {
                if !card.expiration.isEmpty {
                    quickCopyButton(value: card.expiration, field: "exp", label: "Exp: \(card.expiration)")
                }
                if !card.cvv.isEmpty {
                    quickCopyButton(value: card.cvv, field: "cvv", label: "CVV")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var maskedNumber: String {
        let cleanNumber = card.number.replacingOccurrences(of: " ", with: "")
        if cleanNumber.count >= 4 {
            return "**** **** **** " + String(cleanNumber.suffix(4))
        }
        return card.number
    }

    @ViewBuilder
    private func copyButton(value: String, field: String, label: String) -> some View {
        Button {
            copyToClipboard(value, field: field)
        } label: {
            Text(copiedField == field ? "Copied!" : label)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    @ViewBuilder
    private func quickCopyButton(value: String, field: String, label: String) -> some View {
        Button {
            copyToClipboard(value, field: field)
        } label: {
            Text(copiedField == field ? "Copied!" : label)
                .font(.caption2)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
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
