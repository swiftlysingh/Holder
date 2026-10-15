#if os(iOS)
import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 18.0, *)
struct ControlCenterCardWidget: ControlWidget {
    static let kind: String = "ControlCenterCardWidget"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ControlCenterCardIntent.self
        ) { configuration in
            ControlWidgetButton(action: OpenHolderCardIntent(cardID: configuration.card?.id)) {
                let card = configuration.card.flatMap { entity in
                    SharedDataManager.shared.getCard(by: entity.id)
                }

                Label {
                    if let card = card {
                        Text(card.displayName)
                        Text(card.displayText)
                    } else {
                        Text("Holder")
                        Text("Select a card")
                    }
                } icon: {
                    Image(systemName: "creditcard.fill")
                }
            }
        }
        .displayName("Card")
        .description("View card info")
    }
}

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

    func perform() async throws -> some IntentResult {
        // The app will handle the deep link via URL scheme
        return .result()
    }
}
#endif
