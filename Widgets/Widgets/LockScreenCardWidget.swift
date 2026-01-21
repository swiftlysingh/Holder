//
//  LockScreenCardWidget.swift
//  HolderWidgets
//
//  Lock screen widget displaying a single card
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
        let card = configuration.card.flatMap { entity in
            SharedDataManager.shared.getCard(by: entity.id)
        } ?? SharedDataManager.shared.loadAvailableCards().first
        return LockScreenCardEntry(date: Date(), card: card, configuration: configuration)
    }

    func timeline(for configuration: SelectCardIntent, in context: Context) async -> Timeline<LockScreenCardEntry> {
        let card = configuration.card.flatMap { entity in
            SharedDataManager.shared.getCard(by: entity.id)
        } ?? SharedDataManager.shared.loadAvailableCards().first
        let entry = LockScreenCardEntry(date: Date(), card: card, configuration: configuration)
        return Timeline(entries: [entry], policy: .never)
    }
}

// MARK: - Timeline Entry

struct LockScreenCardEntry: TimelineEntry {
    let date: Date
    let card: WidgetCardData?
    let configuration: SelectCardIntent
}

// MARK: - Widget View

struct LockScreenCardWidgetView: View {
    var entry: LockScreenCardEntry
    @Environment(\.widgetFamily) var family

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
            VStack(spacing: 2) {
                Image(systemName: "creditcard.fill")
                    .font(.title3)
                if let card = entry.card {
                    Text(card.lastFourDigits)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .fontDesign(.monospaced)
                }
            }
        }
        .widgetURL(entry.card.map { URL(string: "holder://card/\($0.id.uuidString)") } ?? nil)
    }

    // MARK: - Rectangular View

    private var accessoryRectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "creditcard.fill")
                .font(.title2)

            if let card = entry.card {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(card.displayText)
                        .font(.caption)
                        .fontDesign(.monospaced)
                }
            } else {
                Text("Select a Card")
                    .font(.caption)
            }

            Spacer()
        }
        .widgetURL(entry.card.map { URL(string: "holder://card/\($0.id.uuidString)") } ?? nil)
    }

    // MARK: - Inline View

    @ViewBuilder
    private var accessoryInlineView: some View {
        if let card = entry.card {
            Text("\(card.displayName) \(card.displayText)")
                .widgetURL(URL(string: "holder://card/\(card.id.uuidString)"))
        } else {
            Text("No Card Selected")
        }
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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Lock Screen Card")
        .description("Quick view of a card on lock screen")
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
            displayName: "Axis Visa",
            lastFourDigits: "3456",
            cardType: "Credit Card",
            network: "Visa"
        ),
        configuration: SelectCardIntent()
    )
}
#endif
