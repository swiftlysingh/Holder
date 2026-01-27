//
//  MediumCardWidget.swift
//  HolderWidgets
//
//  Medium home screen widget displaying up to 4 cards
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct MediumCardProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MediumCardEntry {
        MediumCardEntry(date: Date(), cards: [], configuration: SelectMultipleCardsIntent())
    }

    func snapshot(for configuration: SelectMultipleCardsIntent, in context: Context) async -> MediumCardEntry {
        let cardIDs = (configuration.cards ?? []).map { $0.id }
        var cards = SharedDataManager.shared.getCards(by: cardIDs)
        if cards.isEmpty {
            cards = Array(SharedDataManager.shared.loadAvailableCards().prefix(4))
        }
        return MediumCardEntry(date: Date(), cards: Array(cards.prefix(4)), configuration: configuration)
    }

    func timeline(for configuration: SelectMultipleCardsIntent, in context: Context) async -> Timeline<MediumCardEntry> {
        let cardIDs = (configuration.cards ?? []).map { $0.id }
        var cards = SharedDataManager.shared.getCards(by: cardIDs)
        if cards.isEmpty {
            cards = Array(SharedDataManager.shared.loadAvailableCards().prefix(4))
        }
        let entry = MediumCardEntry(date: Date(), cards: Array(cards.prefix(4)), configuration: configuration)
        return Timeline(entries: [entry], policy: .never)
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
    var entry: MediumCardEntry

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        if entry.cards.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "creditcard")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("Select Cards")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(entry.cards.prefix(4)) { card in
                    if let url = URL(string: "holder://card/\(card.id.uuidString)") {
                        Link(destination: url) {
                            CardCellView(card: card)
                        }
                    } else {
                        CardCellView(card: card)
                    }
                }
            }
        }
    }
}

// MARK: - Card Cell View

struct CardCellView: View {
    let card: WidgetCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Text(card.displayText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fontDesign(.monospaced)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Cards")
        .description("Display up to 4 cards")
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
            WidgetCardData(id: UUID(), displayName: "Axis Visa", lastFourDigits: "3456", cardType: "Credit Card", network: "Visa"),
            WidgetCardData(id: UUID(), displayName: "SBI MasterCard", lastFourDigits: "7890", cardType: "Credit Card", network: "Mastercard"),
            WidgetCardData(id: UUID(), displayName: "HDFC Platinum", lastFourDigits: "1234", cardType: "Debit Card", network: "Visa"),
            WidgetCardData(id: UUID(), displayName: "Kotak PVR", lastFourDigits: "5678", cardType: "Debit Card", network: "Rupay")
        ],
        configuration: SelectMultipleCardsIntent()
    )
    MediumCardEntry(date: .now, cards: [], configuration: SelectMultipleCardsIntent())
}
