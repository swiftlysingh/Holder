//
//  SharedDataManager.swift
//  HolderWidgets
//
//  Manages data sharing between main app and widget via App Group
//

import Foundation
import WidgetKit

final class SharedDataManager {
    static let shared = SharedDataManager()

    private let appGroupID = "group.com.swiftlysingh.cards"
    private let availableCardsKey = "widgetAvailableCards"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private init() {}

    // MARK: - Save Methods (called from main app)

    /// Saves available cards to shared storage for widget access
    /// - Note: This method uses JSONEncoder which is incompatible with how the main app
    ///   writes data (using JSONSerialization). Use CardDataStore.syncCardsToWidget() instead.
    @available(*, deprecated, message: "Use CardDataStore.syncCardsToWidget() instead")
    func saveAvailableCards(_ cards: [WidgetCardData]) {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        sharedDefaults?.set(data, forKey: availableCardsKey)
    }

    // MARK: - Load Methods (called from widget)

    /// Loads available cards from shared storage
    func loadAvailableCards() -> [WidgetCardData] {
        guard let data = sharedDefaults?.data(forKey: availableCardsKey),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return jsonArray.compactMap { dict -> WidgetCardData? in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let displayName = dict["displayName"] as? String,
                  let lastFourDigits = dict["lastFourDigits"] as? String,
                  let cardType = dict["cardType"] as? String,
                  let network = dict["network"] as? String else {
                return nil
            }
            return WidgetCardData(
                id: id,
                displayName: displayName,
                lastFourDigits: lastFourDigits,
                cardType: cardType,
                network: network
            )
        }
    }

    /// Gets a specific card by ID
    func getCard(by id: UUID) -> WidgetCardData? {
        loadAvailableCards().first { $0.id == id }
    }

    /// Gets cards by IDs (for medium widget)
    func getCards(by ids: [UUID]) -> [WidgetCardData] {
        let allCards = loadAvailableCards()
        return ids.compactMap { id in allCards.first { $0.id == id } }
    }

    // MARK: - Widget Refresh

    /// Triggers widget timeline refresh
    static func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
