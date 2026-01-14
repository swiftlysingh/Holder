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
        .frame(width: 320)
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
                            displayValue: formatCardNumber(card.number),
                            copyValue: card.number,
                            field: "number"
                        )
                    }

                    // Expiration
                    if !card.expiration.isEmpty {
                        copyableDetailRow(
                            icon: "calendar",
                            label: "Expires",
                            displayValue: card.expiration,
                            copyValue: card.expiration,
                            field: "exp"
                        )
                    }

                    // CVV
                    if !card.cvv.isEmpty {
                        copyableDetailRow(
                            icon: "lock.fill",
                            label: "CVV",
                            displayValue: "•••",
                            copyValue: card.cvv,
                            field: "cvv"
                        )
                    }

                    // Name on card
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
                .padding(.leading, 60) // Align with card name (12 padding + 36 icon + 12 spacing)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
                .background(Color.primary.opacity(0.03))
            }
        }
    }

    @ViewBuilder
    private var networkImage: some View {
        // Check if we have a valid network that's not "Unknown"
        if card.type != .otherCard && card.network != .other {
            Image(card.network.rawValue)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
        } else {
            // Fallback to system icon for unknown networks or other card types
            Image(systemName: "creditcard.fill")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func copyableDetailRow(icon: String, label: String, displayValue: String, copyValue: String, field: String) -> some View {
        Button {
            copyToClipboard(copyValue, field: field)
        } label: {
            HStack(spacing: 0) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(width: iconWidth, alignment: .leading)

                // Label
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: labelWidth, alignment: .leading)

                Spacer()

                // Value or Copied indicator
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
