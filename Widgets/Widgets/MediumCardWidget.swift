//
//  MediumCardWidget.swift
//  HolderWidgets
//
//  A quick grid of card shortcuts for the Home Screen.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct MediumCardProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MediumCardEntry {
        MediumCardEntry(date: Date(), cards: [], configuration: SelectMultipleCardsIntent())
    }

    func snapshot(for configuration: SelectMultipleCardsIntent, in context: Context) async -> MediumCardEntry {
        MediumCardEntry(
            date: Date(),
            cards: selectedCards(for: configuration),
            configuration: configuration
        )
    }

    func timeline(for configuration: SelectMultipleCardsIntent, in context: Context) async -> Timeline<MediumCardEntry> {
        let entry = MediumCardEntry(
            date: Date(),
            cards: selectedCards(for: configuration),
            configuration: configuration
        )
        return Timeline(entries: [entry], policy: .never)
    }

    private func selectedCards(for configuration: SelectMultipleCardsIntent) -> [WidgetCardData] {
        let configuredIDs = (configuration.cards ?? []).map(\.id)
        let configuredCards = SharedDataManager.shared.getCards(by: configuredIDs)

        if configuredCards.isEmpty {
            return Array(SharedDataManager.shared.loadAvailableCards().prefix(4))
        }

        return Array(configuredCards.prefix(4))
    }
}

// MARK: - Timeline Entry

struct MediumCardEntry: TimelineEntry {
    let date: Date
    let cards: [WidgetCardData]
    let configuration: SelectMultipleCardsIntent
}

// MARK: - Widget View

struct MediumCardWidgetView: View {
    let entry: MediumCardEntry

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        if entry.cards.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(entry.cards.prefix(4)) { card in
                    if let url = HolderWidgetURL.card(card) {
                        Link(destination: url) {
                            MediumCardCellView(card: card)
                        }
                    } else {
                        MediumCardCellView(card: card)
                    }
                }
            }
            .privacySensitive()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.grid.2x2")
                .font(.title2)
                .foregroundStyle(HolderWidgetPalette.emerald)
                .accessibilityHidden(true)

            Text("Choose cards")
                .font(.headline)

            Text("Quick shortcuts stay private")
                .font(.caption2)
                .foregroundStyle(HolderWidgetPalette.secondaryOnCanvas)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Holder. Choose cards in the widget settings.")
    }
}

// MARK: - Card Cell View

struct MediumCardCellView: View {
    let card: WidgetCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(card.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(HolderWidgetPalette.secondaryOnCard)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 7)

            Text(card.displayText)
                .font(.caption2.monospacedDigit().weight(.medium))
                .foregroundStyle(HolderWidgetPalette.secondaryOnCard)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(10)
        .background(
            HolderWidgetPalette.cardSurface(for: card),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open the selected card in Holder.")
        .accessibilityHint("Holder will request authentication before revealing card details.")
    }
}

// MARK: - Widget Configuration

struct MediumCardWidget: Widget {
    let kind: String = "MediumCardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectMultipleCardsIntent.self,
            provider: MediumCardProvider()
        ) { entry in
            MediumCardWidgetView(entry: entry)
                .containerBackground(HolderWidgetPalette.mintCanvas, for: .widget)
        }
        .configurationDisplayName("Card shortcuts")
        .description("Open up to four cards in Holder. Details stay private until you authenticate.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    MediumCardWidget()
} timeline: {
    MediumCardEntry(
        date: .now,
        cards: [
			WidgetCardData(id: UUID(), displayName: "Axis Visa", lastFourDigits: "3456", network: "Visa"),
			WidgetCardData(id: UUID(), displayName: "SBI MasterCard", lastFourDigits: "7890", network: "Mastercard"),
			WidgetCardData(id: UUID(), displayName: "HDFC Platinum", lastFourDigits: "1234", network: "Visa"),
			WidgetCardData(id: UUID(), displayName: "Kotak PVR", lastFourDigits: "5678", network: "Rupay")
        ],
        configuration: SelectMultipleCardsIntent()
    )
    MediumCardEntry(date: .now, cards: [], configuration: SelectMultipleCardsIntent())
}
