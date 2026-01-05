//
//  SmallCardWidget.swift
//  HolderWidgets
//
//  Small home screen widget displaying a single card
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct SmallCardProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SmallCardEntry {
        SmallCardEntry(date: Date(), card: nil, configuration: SelectCardIntent())
    }

    func snapshot(for configuration: SelectCardIntent, in context: Context) async -> SmallCardEntry {
        let card = configuration.card.flatMap { entity in
            SharedDataManager.shared.getCard(by: entity.id)
        }
        return SmallCardEntry(date: Date(), card: card, configuration: configuration)
    }

    func timeline(for configuration: SelectCardIntent, in context: Context) async -> Timeline<SmallCardEntry> {
        let card = configuration.card.flatMap { entity in
            SharedDataManager.shared.getCard(by: entity.id)
        }
        let entry = SmallCardEntry(date: Date(), card: card, configuration: configuration)
        return Timeline(entries: [entry], policy: .never)
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
    var entry: SmallCardEntry

    var body: some View {
        if let card = entry.card {
            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                Text(card.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(card.displayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "holder://card/\(card.id.uuidString)"))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "creditcard")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("Select a Card")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Card")
        .description("Display a single card")
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
            cardType: "Credit Card",
            network: "Visa"
        ),
        configuration: SelectCardIntent()
    )
    SmallCardEntry(date: .now, card: nil, configuration: SelectCardIntent())
}
