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
    @State private var copied = false

    var body: some View {
        Button {
            copyCardNumber()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.description.isEmpty ? card.name : card.description)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(maskedNumber)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if copied {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text(card.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var maskedNumber: String {
        let cleanNumber = card.number.replacingOccurrences(of: " ", with: "")
        if cleanNumber.count >= 4 {
            return "**** " + String(cleanNumber.suffix(4))
        }
        return card.number
    }

    private func copyCardNumber() {
        PasteboardService.copy(card.number)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}
#endif
