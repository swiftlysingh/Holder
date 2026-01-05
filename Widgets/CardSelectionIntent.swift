//
//  CardSelectionIntent.swift
//  HolderWidgets
//
//  App Intents for widget card selection configuration
//

import AppIntents
import WidgetKit

// MARK: - Card Entity

struct CardEntity: AppEntity {
    let id: UUID
    let displayName: String
    let lastFourDigits: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Card"
    static var defaultQuery = CardQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName) (**** \(lastFourDigits))")
    }

    init(id: UUID, displayName: String, lastFourDigits: String) {
        self.id = id
        self.displayName = displayName
        self.lastFourDigits = lastFourDigits
    }

    init(from card: WidgetCardData) {
        self.id = card.id
        self.displayName = card.displayName
        self.lastFourDigits = card.lastFourDigits
    }
}

// MARK: - Card Query

struct CardQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CardEntity] {
        let cards = SharedDataManager.shared.loadAvailableCards()
        return identifiers.compactMap { id in
            guard let card = cards.first(where: { $0.id == id }) else { return nil }
            return CardEntity(from: card)
        }
    }

    func suggestedEntities() async throws -> [CardEntity] {
        SharedDataManager.shared.loadAvailableCards().map { CardEntity(from: $0) }
    }

    func defaultResult() async -> CardEntity? {
        guard let card = SharedDataManager.shared.loadAvailableCards().first else { return nil }
        return CardEntity(from: card)
    }
}

// MARK: - Single Card Selection Intent

struct SelectCardIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Card"
    static var description = IntentDescription("Choose which card to display")

    @Parameter(title: "Card")
    var card: CardEntity?

    init() {}

    init(card: CardEntity?) {
        self.card = card
    }
}

// MARK: - Control Center Card Selection Intent (iOS 18+)

@available(iOS 18.0, *)
struct ControlCenterCardIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Select Card"
    static var description = IntentDescription("Choose which card to display")

    @Parameter(title: "Card")
    var card: CardEntity?

    init() {}

    init(card: CardEntity?) {
        self.card = card
    }
}

// MARK: - Multiple Cards Selection Intent

struct SelectMultipleCardsIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Cards"
    static var description = IntentDescription("Choose cards to display (up to 4)")

    @Parameter(title: "Cards")
    var cards: [CardEntity]?

    init() {
        self.cards = []
    }

    init(cards: [CardEntity]) {
        self.cards = cards
    }
}

