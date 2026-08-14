//
//  SmallCardWidget.swift
//  HolderWidgets
//
//  A selected card shortcut for the Home Screen.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct SmallCardProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SmallCardEntry {
        SmallCardEntry(date: Date(), card: nil, configuration: SelectCardIntent())
    }

    func snapshot(for configuration: SelectCardIntent, in context: Context) async -> SmallCardEntry {
        SmallCardEntry(
            date: Date(),
            card: selectedCard(for: configuration),
            configuration: configuration
        )
    }

    func timeline(for configuration: SelectCardIntent, in context: Context) async -> Timeline<SmallCardEntry> {
        let entry = SmallCardEntry(
            date: Date(),
            card: selectedCard(for: configuration),
            configuration: configuration
        )
        return Timeline(entries: [entry], policy: .never)
    }

    private func selectedCard(for configuration: SelectCardIntent) -> WidgetCardData? {
        configuration.card.flatMap { entity in
            SharedDataManager.shared.getCard(by: entity.id)
        } ?? SharedDataManager.shared.loadAvailableCards().first
    }
}

// MARK: - Timeline Entry

struct SmallCardEntry: TimelineEntry {
    let date: Date
    let card: WidgetCardData?
    let configuration: SelectCardIntent
}

// MARK: - Widget View

struct SmallCardWidgetView: View {
    let entry: SmallCardEntry

    var body: some View {
        Group {
            if let card = entry.card {
                selectedCardView(card)
            } else {
                emptyState
            }
        }
    }

    private func selectedCardView(_ card: WidgetCardData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(card.displayName)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 8)

                Text(card.network.uppercased())
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.62), lineWidth: 1)
                    }
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 10)

            HStack(spacing: 7) {
                Image(systemName: "creditcard.fill")
                    .font(.caption)
                    .accessibilityHidden(true)

                Text(card.displayText)
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .lineLimit(1)
            }

            Text("Tap to unlock in Holder")
                .font(.caption2)
                .foregroundStyle(HolderWidgetPalette.secondaryOnCard)
                .padding(.top, 5)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // Home-screen details are intentionally minimal and let iOS redact
        // them in a privacy-sensitive rendering context.
        .privacySensitive()
        .widgetURL(HolderWidgetURL.card(card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open the selected card in Holder.")
        .accessibilityHint("Holder will request authentication before revealing card details.")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(HolderWidgetPalette.emerald)
                .accessibilityHidden(true)

            Text("Add a card")
                .font(.headline)

            Text("Your details stay in Holder")
                .font(.caption2)
                .foregroundStyle(HolderWidgetPalette.secondaryOnCanvas)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Holder. Add a card in the app.")
    }
}

// MARK: - Widget Configuration

struct SmallCardWidget: Widget {
    let kind: String = "SmallCardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectCardIntent.self,
            provider: SmallCardProvider()
        ) { entry in
            SmallCardWidgetView(entry: entry)
                .containerBackground(HolderWidgetPalette.smallBackground(for: entry.card), for: .widget)
        }
        .configurationDisplayName("Card shortcut")
        .description("Open one card in Holder. Details stay private until you authenticate.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    SmallCardWidget()
} timeline: {
    SmallCardEntry(
        date: .now,
        card: WidgetCardData(
            id: UUID(),
            displayName: "Axis Visa",
            lastFourDigits: "3456",
            network: "Visa"
        ),
        configuration: SelectCardIntent()
    )
    SmallCardEntry(date: .now, card: nil, configuration: SelectCardIntent())
}
