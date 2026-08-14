//
//  ControlCenterCardWidget.swift
//  HolderWidgets
//
//  Private Control Center shortcut for a selected card (iOS 18+).
//

#if os(iOS)
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Control Center Widget (iOS 18+)

@available(iOS 18.0, *)
struct ControlCenterCardWidget: ControlWidget {
    static let kind: String = "ControlCenterCardWidget"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ControlCenterCardIntent.self
        ) { configuration in
            ControlWidgetButton(action: OpenHolderCardIntent(cardID: configuration.card?.id)) {
                Label {
                    Text("Holder")
                    Text(configuration.card == nil ? "Select a card" : "Unlock in Holder")
                } icon: {
                    Image(systemName: configuration.card == nil ? "plus.circle.fill" : "lock.shield.fill")
                }
            }
        }
        .displayName("Private card shortcut")
        .description("Open a selected card in Holder without showing card details in Control Center.")
    }
}

// MARK: - Open Holder Card Intent

@available(iOS 18.0, *)
struct OpenHolderCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Card in Holder"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Card ID")
    var cardIDString: String?

    init() {}

    init(cardID: UUID?) {
        self.cardIDString = cardID?.uuidString
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        // Validate the selected ID against the current shared card list. This
        // avoids routing stale Control Center configurations to an arbitrary
        // card while still preserving the selected card's deep-link behavior.
        let destination: URL
        if let cardIDString,
           let cardID = UUID(uuidString: cardIDString),
           SharedDataManager.shared.getCard(by: cardID) != nil,
           let cardURL = HolderWidgetURL.card(cardID) {
            destination = cardURL
        } else {
            // The app still opens for an unconfigured/stale control, but its
            // deep-link handler will intentionally select nothing.
            destination = URL(string: "holder://open")!
        }

        return .result(opensIntent: OpenURLIntent(destination))
    }
}
#endif
