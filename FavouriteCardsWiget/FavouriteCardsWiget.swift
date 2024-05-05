//
//  FavouriteCardsWiget.swift
//  FavouriteCardsWiget
//
//  Created by Pushpinder Pal Singh on 04/05/24.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), emoji: "😀")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), emoji: "😀")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleEntry(date: .now, emoji: "😀")
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let emoji: String
}

struct FavouriteCardsWigetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        HStack{
            VStack(alignment: .leading) {
                Image("4".getCardNetwork().rawValue)
                Text("Axis Magnus")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            Spacer()
        }
    }
}

struct FavouriteCardsWiget: Widget {
    let kind: String = "FavouriteCardsWiget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                FavouriteCardsWigetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                FavouriteCardsWigetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

#Preview(as: .systemSmall) {
    FavouriteCardsWiget()
} timeline: {
    SimpleEntry(date: .now, emoji: "😀")
    SimpleEntry(date: .now, emoji: "🤩")
}
