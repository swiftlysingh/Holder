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
                .frame(maxHeight: 400)
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
        .frame(width: 300)
    }

    private var allCards: [CardData] {
        CardType.allCases.flatMap { cardStore.cardsByType[$0] ?? [] }
    }

    private func openMainApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

struct MenuBarCardRow: View {
    let card: CardData
    @State private var copiedField: String?
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card header - tap to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // Network logo
                    if card.type != .otherCard {
                        Image(card.network.rawValue)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 24)
                    } else {
                        Image(systemName: "creditcard.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 32)
                    }

                    // Card name and masked number
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cardDisplayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(maskedNumber)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                VStack(spacing: 0) {
                    // Card Number
                    copyableRow(
                        icon: "number",
                        label: "Number",
                        value: formatCardNumber(card.number),
                        field: "number",
                        actualValue: card.number
                    )

                    // Expiration
                    if !card.expiration.isEmpty {
                        Divider().padding(.leading, 44)
                        copyableRow(
                            icon: "calendar",
                            label: "Expires",
                            value: card.expiration,
                            field: "exp",
                            actualValue: card.expiration
                        )
                    }

                    // CVV
                    if !card.cvv.isEmpty {
                        Divider().padding(.leading, 44)
                        copyableRow(
                            icon: "lock.fill",
                            label: "CVV",
                            value: "•••",
                            field: "cvv",
                            actualValue: card.cvv
                        )
                    }

                    // Name on card
                    if !card.name.isEmpty {
                        Divider().padding(.leading, 44)
                        copyableRow(
                            icon: "person.fill",
                            label: "Name",
                            value: card.name,
                            field: "name",
                            actualValue: card.name
                        )
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private func copyableRow(icon: String, label: String, value: String, field: String, actualValue: String) -> some View {
        Button {
            copyToClipboard(actualValue, field: field)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 32)

                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if copiedField == field {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Copied!")
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                } else {
                    Text(value)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
