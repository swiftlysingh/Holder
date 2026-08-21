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
private final class CardKeychainPersistence: @unchecked Sendable {
	typealias RetrievePayloads = @Sendable (String) -> CardPayloadRetrievalResult
	typealias SavePayload = @Sendable (Data, String, String) -> Bool
	typealias DeletePayload = @Sendable (String, String) -> Bool

	private static let queue = DispatchQueue(
		label: "com.swiftlysingh.holder.keychain",
		qos: .userInitiated
	)

	private let retrievePayloads: RetrievePayloads
	private let savePayload: SavePayload
	private let deletePayload: DeletePayload

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

	func save(_ payload: Data, service: String, account: String) async -> Bool {
		let savePayload = savePayload
		return await Self.execute {
			savePayload(payload, service, account)
		}
	}

	func delete(service: String, account: String) async -> Bool {
		let deletePayload = deletePayload
		return await Self.execute {
			deletePayload(service, account)
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

/// Serializes complete card mutations, including their in-memory commits.
private actor CardMutationGate {
	private var isLocked = false
	private var waiters: [CheckedContinuation<Void, Never>] = []

	func acquire() async {
		guard isLocked else {
			isLocked = true
			return
		}

		await withCheckedContinuation { continuation in
			waiters.append(continuation)
		}
	}

	func release() {
		guard !waiters.isEmpty else {
			isLocked = false
			return
		}

		waiters.removeFirst().resume()
	}
}

@MainActor
@Observable
final class CardDataStore {
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
	private let imageStore: CardImageStore
	@ObservationIgnored
	private let beforeApplyingLoad: () async -> Void
	@ObservationIgnored
	private let mutationGate = CardMutationGate()
	private var latestLoadGeneration: UInt64 = 0
	private var hasCompletedSuccessfulLoad = false

	init(
		retrievePayloads: (@Sendable (String) -> CardPayloadRetrievalResult)? = nil,
		savePayload: (@Sendable (Data, String, String) -> Bool)? = nil,
		deletePayload: (@Sendable (String, String) -> Bool)? = nil,
		imageStore: CardImageStore = ICloudDataManager.shared,
		beforeApplyingLoad: @escaping () async -> Void = {}
	) {
		persistence = CardKeychainPersistence(
			retrievePayloads: retrievePayloads ?? { Self.retrieveAllCardPayloads(service: $0) },
			savePayload: savePayload ?? { Self.saveCardPayload($0, service: $1, account: $2) },
			deletePayload: deletePayload ?? { Self.deleteCardPayload(service: $0, account: $1) }
		)
		self.imageStore = imageStore
		self.beforeApplyingLoad = beforeApplyingLoad
	}

	/// iCloud Keychain operations can stall for seconds, so all retrieval happens
	/// on the serial persistence queue and only the resulting state is published here.
	@discardableResult
	func loadCards() async -> Bool {
		latestLoadGeneration &+= 1
		let loadGeneration = latestLoadGeneration
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
		guard loadGeneration == latestLoadGeneration else { return true }

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
				if await saveCardData(fixture, service: service) {
					retrievedCards.append(fixture)
				}
			}
		}
		if isDebugOrSimulator && !hasInitializedDebugFixtures && !retrievedCards.isEmpty {
			UserDefaults.standard.set(true, forKey: debugFixturesInitializedKey)
		}
		#endif

		guard loadGeneration == latestLoadGeneration else { return true }
		commitCards(retrievedCards)
		return true
	}

	private func commitCards(_ cards: [CardData]) {
		let partition = Self.partition(cards)
		cardsByType = partition.cardsByType
		archivedCards = partition.archivedCards
		hasCompletedSuccessfulLoad = true
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
		guard !payloads.isEmpty else { return [] }
		let decoder = JSONDecoder()
		let cards = payloads.compactMap { payload in
			payload.flatMap { try? decoder.decode(CardData.self, from: $0) }
		}
		return cards.isEmpty ? nil : cards
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
		await persistCard(card, requiresExistingCard: false)
	}

	@discardableResult
	func updateCard(_ card: CardData) async -> Bool {
		await persistCard(card, requiresExistingCard: true)
	}

	private func persistCard(_ card: CardData, requiresExistingCard: Bool) async -> Bool {
		await performMutation {
			guard requiresExistingCard == (self.storedCard(by: card.id) != nil) else { return false }
			guard await self.saveCardData(card) else {
				print("Failed to save card: \(card.id)")
				return false
			}
			self.commitUpsert(card)
			return true
		}
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
		await performMutation {
			guard let card = self.storedCard(by: id) else { return false }

			let service = Bundle.main.bundleIdentifier ?? "com.myApp.defaultService"
			guard await self.persistence.delete(service: service, account: id.uuidString) else { return false }

			self.commitRemoval(of: id)
			if card.type == .otherCard {
				_ = await self.imageStore.deleteImage(for: id)
			}
			return true
		}
	}

	// MARK: - Archive

	@discardableResult
	func archiveCard(_ card: CardData) async -> Bool {
		await updateArchiveState(for: card.id, isArchived: true)
	}

	@discardableResult
	func unarchiveCard(_ card: CardData) async -> Bool {
		await updateArchiveState(for: card.id, isArchived: false)
	}

	private func updateArchiveState(for id: UUID, isArchived: Bool) async -> Bool {
		await performMutation {
			guard var currentCard = self.storedCard(by: id) else { return false }
			currentCard.isArchived = isArchived
			guard await self.saveCardData(currentCard) else {
				print("Failed to update archive state: \(id)")
				return false
			}
			self.commitUpsert(currentCard)
			return true
		}
	}

	private func performMutation(
		_ operation: @escaping @MainActor () async -> Bool
	) async -> Bool {
		await mutationGate.acquire()

		if !hasCompletedSuccessfulLoad {
			let didLoad = await loadCards()
			guard didLoad && hasCompletedSuccessfulLoad else {
				await mutationGate.release()
				return false
			}
		}

		latestLoadGeneration &+= 1
		let result = await operation()
		await mutationGate.release()
		return result
	}

	private func storedCard(by id: UUID) -> CardData? {
		findCard(by: id) ?? archivedCards.first { $0.id == id }
	}

	private var allStoredCards: [CardData] {
		CardType.allCases.flatMap { cardsByType[$0] ?? [] } + archivedCards
	}

	private func commitUpsert(_ card: CardData) {
		var cards = allStoredCards
		if let index = cards.firstIndex(where: { $0.id == card.id }) {
			cards[index] = card
		} else {
			cards.append(card)
		}
		commitCards(cards)
	}

	private func commitRemoval(of id: UUID) {
		commitCards(allStoredCards.filter { $0.id != id })
	}

	private func saveCardData(
		_ cardData: CardData,
		service: String? = nil
	) async -> Bool {
		guard let cardDataEncoded = try? JSONEncoder().encode(cardData) else {
			print("Failed to encode CardData")
			return false
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
