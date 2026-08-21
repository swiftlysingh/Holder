//
//  CardDataStore.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 07/01/24.
//
import SwiftUI
import WidgetKit

enum CardPayloadRetrievalResult: Sendable {
	case success([Data?])
	case empty
	case failure
}

/// Executes synchronizable Keychain work on one serial, non-main queue.
/// `queue` confines the mutation sequence used to order async completions.
private final class CardKeychainPersistence: @unchecked Sendable {
	typealias RetrievePayloads = @Sendable (String) -> CardPayloadRetrievalResult
	typealias SavePayload = @Sendable (Data, String, String) -> Bool
	typealias DeletePayload = @Sendable (String, String) -> Bool
	struct MutationResult: Sendable {
		let succeeded: Bool
		let sequence: UInt64
	}

	private static let queue = DispatchQueue(
		label: "com.swiftlysingh.holder.keychain",
		qos: .userInitiated
	)

	private let retrievePayloads: RetrievePayloads
	private let savePayload: SavePayload
	private let deletePayload: DeletePayload
	private var nextMutationSequence: UInt64 = 0

	init(
		retrievePayloads: @escaping RetrievePayloads,
		savePayload: @escaping SavePayload,
		deletePayload: @escaping DeletePayload
	) {
		self.retrievePayloads = retrievePayloads
		self.savePayload = savePayload
		self.deletePayload = deletePayload
	}

	func retrieve(service: String) async -> CardPayloadRetrievalResult {
		let retrievePayloads = retrievePayloads
		return await Self.execute {
			retrievePayloads(service)
		}
	}

	func save(_ payload: Data, service: String, account: String) async -> MutationResult {
		let savePayload = savePayload
		return await Self.execute { [self] in
			let succeeded = savePayload(payload, service, account)
			nextMutationSequence &+= 1
			return MutationResult(succeeded: succeeded, sequence: nextMutationSequence)
		}
	}

	func delete(service: String, account: String) async -> MutationResult {
		let deletePayload = deletePayload
		return await Self.execute { [self] in
			let succeeded = deletePayload(service, account)
			nextMutationSequence &+= 1
			return MutationResult(succeeded: succeeded, sequence: nextMutationSequence)
		}
	}

	private static func execute<Value: Sendable>(
		_ operation: @escaping @Sendable () -> Value
	) async -> Value {
		await withCheckedContinuation { continuation in
			queue.async {
				continuation.resume(returning: operation())
			}
		}
	}
}

@MainActor
@Observable
final class CardDataStore {
	private enum Mutation {
		case upsert(CardData)
		case delete(UUID)

		func applying(to cards: [CardData]) -> [CardData] {
			var cards = cards
			switch self {
			case .upsert(let card):
				if let index = cards.firstIndex(where: { $0.id == card.id }) {
					cards[index] = card
				} else {
					cards.append(card)
				}
			case .delete(let id):
				cards.removeAll { $0.id == id }
			}
			return cards
		}
	}

	private struct RecordedMutation {
		let generation: UInt64
		let mutation: Mutation
	}

	var cardsByType: [CardType: [CardData]] = [:]
	var archivedCards: [CardData] = []

	// MARK: - Widget Data Sharing

	private let appGroupID = "group.com.swiftlysingh.cards"
	private let widgetCardsKey = "widgetAvailableCards"
	private let debugFixturesInitializedKey = "debugFixturesInitialized"

	private var sharedDefaults: UserDefaults? {
		UserDefaults(suiteName: appGroupID)
	}

	private let isDebugOrSimulator = {
	#if DEBUG || BETA
		return true
	#else
		return false
	#endif
	}()

	/// Distinguishes confirmed empty Keychain results from Security failures.
	enum CardRetrievalKind: Equatable {
		case success
		case empty
		case failure
	}

	@ObservationIgnored
	private let persistence: CardKeychainPersistence
	@ObservationIgnored
	private let beforeApplyingLoad: () async -> Void
	@ObservationIgnored
	private let beforeApplyingMutation: (UInt64) async -> Void
	private var mutationGeneration: UInt64 = 0
	private var activeLoadCount = 0
	private var mutationsDuringLoads: [RecordedMutation] = []
	private var latestAppliedMutationSequenceByCard: [UUID: UInt64] = [:]

	init(
		retrievePayloads: (@Sendable (String) -> CardPayloadRetrievalResult)? = nil,
		savePayload: (@Sendable (Data, String, String) -> Bool)? = nil,
		deletePayload: (@Sendable (String, String) -> Bool)? = nil,
		beforeApplyingLoad: @escaping () async -> Void = {},
		beforeApplyingMutation: @escaping (UInt64) async -> Void = { _ in }
	) {
		persistence = CardKeychainPersistence(
			retrievePayloads: retrievePayloads ?? { Self.retrieveAllCardPayloads(service: $0) },
			savePayload: savePayload ?? { Self.saveCardPayload($0, service: $1, account: $2) },
			deletePayload: deletePayload ?? { Self.deleteCardPayload(service: $0, account: $1) }
		)
		self.beforeApplyingLoad = beforeApplyingLoad
		self.beforeApplyingMutation = beforeApplyingMutation
	}

	/// iCloud Keychain operations can stall for seconds, so all retrieval happens
	/// on the serial persistence queue and only the resulting state is published here.
	@discardableResult
	func loadCards() async -> Bool {
		let loadGeneration = mutationGeneration
		activeLoadCount += 1
		defer {
			activeLoadCount -= 1
			if activeLoadCount == 0 {
				mutationsDuringLoads.removeAll()
			}
		}
		let service = Bundle.main.bundleIdentifier ?? "com.myApp.defaultService"
		switch await persistence.retrieve(service: service) {
		case .failure:
			// Preserve in-memory cards and widget snapshot on real Keychain/decode errors.
			return false
		case .empty:
			return await commitRetrievedCards([], loadGeneration: loadGeneration, service: service)
		case .success(let payloads):
			guard let cards = Self.decodeAllCardData(from: payloads) else {
				print("Error decoding CardData: missing or invalid Keychain payload")
				return false
			}
			if cards.count != payloads.count {
				print("Warning: skipped \(payloads.count - cards.count) invalid Keychain card payload(s)")
			}
			return await commitRetrievedCards(cards, loadGeneration: loadGeneration, service: service)
		}
	}

	private func commitRetrievedCards(
		_ cards: [CardData],
		loadGeneration: UInt64,
		service: String
	) async -> Bool {
		await beforeApplyingLoad()

		var retrievedCards = cards
		let hasInitializedDebugFixtures = UserDefaults.standard.bool(forKey: debugFixturesInitializedKey)

		#if DEBUG || BETA
		if Self.shouldSeedDebugFixtures(
			isDebugOrSimulator: isDebugOrSimulator,
			hasStoredCards: !retrievedCards.isEmpty,
			hasInitializedFixtures: hasInitializedDebugFixtures
		) {
			let fixtures = [
				CardData(
					id: UUID(),
					number: "4242424242424242",
					cvv: "123",
					expiration: "09/29",
					name: "M. C. Lovin",
					description: "Everyday Card",
					type: .creditCard,
					network: "4242424242424242".getCardNetwork()
				),
				CardData(
					id: UUID(),
					number: "5555555555554444",
					cvv: "444",
					expiration: "04/30",
					name: "M. C. Lovin",
					description: "Rewards Card",
					type: .creditCard,
					network: "5555555555554444".getCardNetwork()
				),
				CardData(
					id: UUID(),
					number: "4000056655665556",
					cvv: "789",
					expiration: "11/29",
					name: "M. C. Lovin",
					description: "Travel Debit",
					type: .debitCard,
					network: "4000056655665556".getCardNetwork()
				),
				CardData(
					id: UUID(),
					number: "9000000000004821",
					cvv: "",
					expiration: "06/31",
					name: "M. C. Lovin",
					description: "Health ID",
					type: .otherCard
				)
			]
			for fixture in fixtures {
				if (await saveCardData(fixture, service: service)).succeeded {
					retrievedCards.append(fixture)
				}
			}
		}
		if isDebugOrSimulator && !hasInitializedDebugFixtures && !retrievedCards.isEmpty {
			UserDefaults.standard.set(true, forKey: debugFixturesInitializedKey)
		}
		#endif

		let mergedCards = mutationsDuringLoads
			.filter { $0.generation > loadGeneration }
			.reduce(retrievedCards) { cards, recordedMutation in
				recordedMutation.mutation.applying(to: cards)
			}
		commitCards(mergedCards)
		return true
	}

	private func commitCards(_ cards: [CardData]) {
		let partition = Self.partition(cards)
		cardsByType = partition.cardsByType
		archivedCards = partition.archivedCards
		syncCardsToWidget()
	}

	nonisolated static func cardRetrievalKind(forStatus status: OSStatus) -> CardRetrievalKind {
		switch status {
		case errSecSuccess:
			return .success
		case errSecItemNotFound:
			return .empty
		default:
			return .failure
		}
	}

	/// Decodes every usable Keychain payload. A non-empty batch fails only when no
	/// records can be recovered, preserving existing in-memory state on total corruption.
	static func decodeAllCardData(from payloads: [Data?]) -> [CardData]? {
		var cards: [CardData] = []
		cards.reserveCapacity(payloads.count)
		var hadInvalidPayload = false
		for payload in payloads {
			guard let data = payload else {
				hadInvalidPayload = true
				continue
			}
			do {
				cards.append(try JSONDecoder().decode(CardData.self, from: data))
			} catch {
				hadInvalidPayload = true
			}
		}
		if cards.isEmpty && hadInvalidPayload {
			return nil
		}
		return cards
	}

	static func shouldSeedDebugFixtures(
		isDebugOrSimulator: Bool,
		hasStoredCards: Bool,
		hasInitializedFixtures: Bool
	) -> Bool {
		isDebugOrSimulator && !hasStoredCards && !hasInitializedFixtures
	}

	static func partition(_ cards: [CardData]) -> (cardsByType: [CardType: [CardData]], archivedCards: [CardData]) {
		let activeCards = cards.filter { !$0.isArchived }
		let cardsByType = Dictionary(uniqueKeysWithValues: CardType.allCases.map { type in
			(type, activeCards.filter { $0.type == type })
		})
		return (cardsByType, cards.filter { $0.isArchived })
	}

	@discardableResult
	func addCard(_ card: CardData) async -> Bool {
		let result = await saveCardData(card)
		guard result.succeeded else {
			print("Failed to save card: \(card.id)")
			return false
		}
		await beforeApplyingMutation(result.sequence)
		guard shouldApplyMutation(result, to: card.id) else { return true }
		commitMutation(replacing: card)
		return true
	}

	/// Finds a card by its UUID (used for deep linking from widgets)
	func findCard(by id: UUID) -> CardData? {
		for type in CardType.allCases {
			if let cards = cardsByType[type], let card = cards.first(where: { $0.id == id }) {
				return card
			}
		}
		return nil
	}

	func deleteCard(with id: UUID) async -> Bool {
		let service = Bundle.main.bundleIdentifier ?? "com.myApp.defaultService"
		let result = await persistence.delete(service: service, account: id.uuidString)
		guard result.succeeded else {
			return false
		}
		await beforeApplyingMutation(result.sequence)
		guard shouldApplyMutation(result, to: id) else { return true }

		recordMutation(.delete(id))
		commitCards(allCards.filter { $0.id != id })
		return true
	}

	// MARK: - Archive

	@discardableResult
	func archiveCard(_ card: CardData) async -> Bool {
		var archivedCard = card
		archivedCard.isArchived = true
		let result = await saveCardData(archivedCard)
		guard result.succeeded else {
			print("Failed to archive card: \(card.id)")
			return false
		}
		await beforeApplyingMutation(result.sequence)
		guard shouldApplyMutation(result, to: card.id) else { return true }
		commitMutation(replacing: archivedCard)
		return true
	}

	@discardableResult
	func unarchiveCard(_ card: CardData) async -> Bool {
		var unarchivedCard = card
		unarchivedCard.isArchived = false
		let result = await saveCardData(unarchivedCard)
		guard result.succeeded else {
			print("Failed to unarchive card: \(card.id)")
			return false
		}
		await beforeApplyingMutation(result.sequence)
		guard shouldApplyMutation(result, to: card.id) else { return true }
		commitMutation(replacing: unarchivedCard)
		return true
	}

	private var allCards: [CardData] {
		CardType.allCases.flatMap { cardsByType[$0] ?? [] } + archivedCards
	}

	private func commitMutation(replacing card: CardData) {
		recordMutation(.upsert(card))
		var updatedCards = allCards
		if let index = updatedCards.firstIndex(where: { $0.id == card.id }) {
			updatedCards[index] = card
		} else {
			updatedCards.append(card)
		}
		commitCards(updatedCards)
	}

	private func recordMutation(_ mutation: Mutation) {
		mutationGeneration &+= 1
		if activeLoadCount > 0 {
			mutationsDuringLoads.append(RecordedMutation(
				generation: mutationGeneration,
				mutation: mutation
			))
		}
	}

	private func shouldApplyMutation(
		_ result: CardKeychainPersistence.MutationResult,
		to cardID: UUID
	) -> Bool {
		guard result.sequence > latestAppliedMutationSequenceByCard[cardID, default: 0] else {
			return false
		}
		latestAppliedMutationSequenceByCard[cardID] = result.sequence
		return true
	}

	private func saveCardData(
		_ cardData: CardData,
		service: String? = nil
	) async -> CardKeychainPersistence.MutationResult {
		guard let cardDataEncoded = try? JSONEncoder().encode(cardData) else {
			print("Failed to encode CardData")
			return CardKeychainPersistence.MutationResult(succeeded: false, sequence: 0)
		}
		return await persistence.save(
			cardDataEncoded,
			service: service ?? Bundle.main.bundleIdentifier ?? "com.myApp.defaultService",
			account: cardData.id.uuidString
		)
	}

	nonisolated private static func saveCardPayload(
		_ cardDataEncoded: Data,
		service: String,
		account: String
	) -> Bool {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
			kSecAttrSynchronizable as String : kCFBooleanTrue!
		]

		// Check if item already exists
		let status = SecItemCopyMatching(query as CFDictionary, nil)

		if status == errSecItemNotFound {
			// Add a new item
			var newItem = query
			newItem[kSecValueData as String] = cardDataEncoded
			return SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess
		} else if status == errSecSuccess {
			// Update existing item
			let updateAttributes: [String: Any] = [kSecValueData as String: cardDataEncoded]

			return SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary) == errSecSuccess
		} else {
			// Handle other errors
			print("Error checking for existing Keychain item: \(status)")
			return false
		}
	}

	nonisolated private static func deleteCardPayload(service: String, account: String) -> Bool {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
			kSecAttrSynchronizable as String: kCFBooleanTrue!
		]
		return SecItemDelete(query as CFDictionary) == errSecSuccess
	}

	nonisolated private static func retrieveAllCardPayloads(service: String) -> CardPayloadRetrievalResult {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecMatchLimit as String: kSecMatchLimitAll,
			kSecReturnAttributes as String: kCFBooleanTrue!,
			kSecReturnData as String: kCFBooleanTrue!,
			kSecAttrSynchronizable as String: kCFBooleanTrue!
		]

		var items: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &items)

		switch Self.cardRetrievalKind(forStatus: status) {
		case .empty:
			print("No items found in the Keychain")
			return .empty
		case .failure:
			print("Error retrieving from Keychain: \(status)")
			return .failure
		case .success:
			break
		}

		guard let existingItems = items as? [[String: Any]] else {
			print("Error retrieving from Keychain: unexpected item payload")
			return .failure
		}

		let payloads = existingItems.map { $0[kSecValueData as String] as? Data }
		return .success(payloads)
	}

	// MARK: - Widget Sync

	/// Syncs card data to widget via App Group (only safe display data, no sensitive info)
	func syncCardsToWidget() {
		let allCards = CardType.allCases.flatMap { cardsByType[$0] ?? [] }
		let widgetCards = allCards.map { card -> [String: Any] in
			let cleanNumber = card.number.replacingOccurrences(of: " ", with: "")
			let lastFour = String(cleanNumber.suffix(4))
			let displayName = card.description.isEmpty ? card.name : card.description
			return [
				"id": card.id.uuidString,
				"displayName": displayName,
				"lastFourDigits": lastFour,
				"cardType": card.type.rawValue,
				"network": card.network.rawValue
			]
		}

		if let data = try? JSONSerialization.data(withJSONObject: widgetCards) {
			sharedDefaults?.set(data, forKey: widgetCardsKey)
		}
		WidgetCenter.shared.reloadAllTimelines()
	}

}
