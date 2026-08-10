//
//  LockScreenCardWidget.swift
//  HolderWidgets
//
//  A masked lock-screen shortcut. The circular family stays generic; inline
//  families show only the selected display label and masked tail from the
//  widget-safe projection. Full numbers, expiry, CVV, and documents never enter
//  this timeline.
//

#if os(iOS)
import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct LockScreenCardProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LockScreenCardEntry {
        LockScreenCardEntry(date: Date(), card: nil, configuration: SelectCardIntent())
    }

    func snapshot(for configuration: SelectCardIntent, in context: Context) async -> LockScreenCardEntry {
        LockScreenCardEntry(
            date: Date(),
            card: selectedCard(for: configuration),
            configuration: configuration
        )
    }

    func timeline(for configuration: SelectCardIntent, in context: Context) async -> Timeline<LockScreenCardEntry> {
        let entry = LockScreenCardEntry(
            date: Date(),
            card: selectedCard(for: configuration),
            configuration: configuration
        )
        return Timeline(entries: [entry], policy: .never)
    }

    private func selectedCard(for configuration: SelectCardIntent) -> WidgetCardData? {
        if let configuredID = configuration.card?.id,
           let configuredCard = SharedDataManager.shared.getCard(by: configuredID) {
            return configuredCard
        }

        return SharedDataManager.shared.loadAvailableCards().first
    }
}

// MARK: - Timeline Entry

struct LockScreenCardEntry: TimelineEntry {
    let date: Date
    /// Widget-safe state only: a display label and masked tail. Sensitive card
    /// fields and all document data remain in the authenticated app.
    let card: WidgetCardData?
    let configuration: SelectCardIntent
}

// MARK: - Widget View

struct LockScreenCardWidgetView: View {
    let entry: LockScreenCardEntry
    @Environment(\.widgetFamily) private var family

    private var hasCardShortcut: Bool {
        entry.card != nil
    }

    private var destination: URL? {
        entry.card.flatMap { HolderWidgetURL.card($0.id) }
    }

    private var maskedTail: String? {
        guard let tail = entry.card?.lastFourDigits, !tail.isEmpty else { return nil }
        return "•• \(tail)"
    }

    private var selectedCardAccessibilityLabel: String? {
        guard let card = entry.card else { return nil }
        if !card.lastFourDigits.isEmpty {
            return "\(card.displayName), card ending in \(card.lastFourDigits)."
        }
        return "\(card.displayName), card details masked."
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryInline:
            accessoryInlineView
        default:
            accessoryRectangularView
        }
    }

    // MARK: - Circular View

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: hasCardShortcut ? "lock.shield.fill" : "plus.circle.fill")
                .font(.title3)
                .accessibilityHidden(true)
        }
        .widgetURL(destination)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasCardShortcut ? "Holder is ready to unlock." : "Holder. Add a card in the app.")
    }

    // MARK: - Rectangular View

    private var accessoryRectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: hasCardShortcut ? "lock.shield.fill" : "plus.circle.fill")
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.card?.displayName ?? "Holder")
                    .font(.headline)
                    .lineLimit(1)

                Text(maskedTail ?? (hasCardShortcut ? "Details masked" : "Add a card in the app"))
                    .font(.caption)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .widgetURL(destination)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selectedCardAccessibilityLabel ?? "Holder. Add a card in the app.")
        .accessibilityHint(hasCardShortcut ? "Opens Holder and requests authentication." : "Open Holder to add a card.")
    }

    // MARK: - Inline View

    private var accessoryInlineView: some View {
        Text(entry.card.map { card in
            let tail = card.lastFourDigits.isEmpty ? "masked" : "•• \(card.lastFourDigits)"
            return "\(card.displayName) \(tail)"
        } ?? "Holder: add a card")
            .widgetURL(destination)
            .accessibilityLabel(selectedCardAccessibilityLabel ?? "Holder. Add a card in the app.")
            .accessibilityHint(hasCardShortcut ? "Opens Holder and requests authentication." : "Open Holder to add a card.")
    }
}

// MARK: - Widget Configuration

struct LockScreenCardWidget: Widget {
    let kind: String = "LockScreenCardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectCardIntent.self,
            provider: LockScreenCardProvider()
        ) { entry in
            LockScreenCardWidgetView(entry: entry)
                .foregroundStyle(.white)
                .containerBackground(HolderWidgetPalette.ink, for: .widget)
        }
        .configurationDisplayName("Private card shortcut")
        .description("Shows a selected card's masked identity and opens it in Holder for authentication.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    LockScreenCardWidget()
} timeline: {
    LockScreenCardEntry(
        date: .now,
        card: WidgetCardData(
            id: UUID(),
            displayName: "Amex Platinum",
            lastFourDigits: "5106",
            network: "Amex"
        ),
        configuration: SelectCardIntent()
    )
    LockScreenCardEntry(date: .now, card: nil, configuration: SelectCardIntent())
}
#endif
