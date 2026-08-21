import XCTest
@testable import Holder

@MainActor
final class CardDataPersistenceTests: XCTestCase {
	func testArchivedCardRoundTripPreservesState() throws {
		var card = makeCard(id: UUID(), isArchived: true)
		card.network = .master

		let data = try JSONEncoder().encode(card)
		let decoded = try JSONDecoder().decode(CardData.self, from: data)

		XCTAssertTrue(decoded.isArchived)
		XCTAssertEqual(decoded.network, .master)
	}

	func testLegacyCardDefaultsToActiveAndDerivesNetwork() throws {
		let id = UUID()
		let data = try JSONSerialization.data(withJSONObject: [
			"id": id.uuidString,
			"number": "4111111111111111",
			"cvv": "123",
			"expiration": "12/30",
			"name": "Legacy Card",
			"description": "",
			"type": CardType.creditCard.rawValue
		])

		let card = try JSONDecoder().decode(CardData.self, from: data)

		XCTAssertEqual(card.id, id)
		XCTAssertEqual(card.network, .visa)
		XCTAssertFalse(card.isArchived)
	}

	func testPartitionSeparatesActiveAndArchivedCards() {
		let creditCard = makeCard(id: UUID())
		let debitCard = makeCard(id: UUID(), type: .debitCard)
		let archivedCard = makeCard(id: UUID(), type: .otherCard, isArchived: true)

		let partition = CardDataStore.partition([creditCard, debitCard, archivedCard])
		let activeCards = CardType.allCases.flatMap { partition.cardsByType[$0] ?? [] }

		XCTAssertEqual(activeCards.count, 2)
		XCTAssertEqual(Set(activeCards.map(\.id)), [creditCard.id, debitCard.id])
		XCTAssertEqual(partition.archivedCards.map(\.id), [archivedCard.id])
	}

	func testCardRetrievalKindDistinguishesEmptyFromFailure() {
		XCTAssertEqual(CardDataStore.cardRetrievalKind(forStatus: errSecSuccess), .success)
		XCTAssertEqual(CardDataStore.cardRetrievalKind(forStatus: errSecItemNotFound), .empty)
		XCTAssertEqual(CardDataStore.cardRetrievalKind(forStatus: errSecAuthFailed), .failure)
		XCTAssertEqual(CardDataStore.cardRetrievalKind(forStatus: errSecInteractionNotAllowed), .failure)
	}

	func testLoadCardsReportsFailureAndPreservesExistingCards() async throws {
		let fixturesKey = "debugFixturesInitialized"
		let previousFixturesValue = UserDefaults.standard.object(forKey: fixturesKey)
		UserDefaults.standard.set(true, forKey: fixturesKey)
		defer {
			if let previousFixturesValue {
				UserDefaults.standard.set(previousFixturesValue, forKey: fixturesKey)
			} else {
				UserDefaults.standard.removeObject(forKey: fixturesKey)
			}
		}

		let card = makeCard(id: UUID())
		let stub = CardPayloadRetrievalStub(result: .success([try card.toData()]))
		let store = CardDataStore(
			retrievePayloads: { _ in stub.result },
			savePayload: { _, _, _ in false },
			deletePayload: { _, _ in false }
		)

		XCTAssertTrue(await store.loadCards())
		XCTAssertEqual(store.findCard(by: card.id), card)

		stub.result = .failure
		XCTAssertFalse(await store.loadCards())
		XCTAssertEqual(store.findCard(by: card.id), card)

		stub.result = .empty
		XCTAssertTrue(await store.loadCards())
		// Sample/debug cards use fresh UUIDs, so the previously stubbed id must not resolve.
		XCTAssertNil(store.findCard(by: card.id))
	}

	func testKeychainReadsWritesAndDeletesRunOffTheMainThread() async throws {
		let storedCard = makeCard(id: UUID())
		let newCard = makeCard(id: UUID())
		let storedPayload = try storedCard.toData()
		let recorder = KeychainOperationRecorder()
		let store = CardDataStore(
			retrievePayloads: { _ in
				recorder.record(.retrieve)
				return .success([storedPayload])
			},
			savePayload: { _, _, _ in
				recorder.record(.save)
				return true
			},
			deletePayload: { _, _ in
				recorder.record(.delete)
				return true
			}
		)

		XCTAssertTrue(await store.loadCards())
		XCTAssertTrue(await store.addCard(newCard))
		XCTAssertTrue(await store.deleteCard(with: storedCard.id))

		XCTAssertEqual(recorder.operations, [.retrieve, .save, .delete])
		XCTAssertTrue(recorder.allOperationsRanOffMainThread)
	}

	func testLateLoadMergesNewerMutationWithoutHidingExistingCards() async throws {
		let existingCard = makeCard(id: UUID())
		let newerCard = makeCard(id: UUID())
		let existingPayload = try existingCard.toData()
		let gate = LoadCommitGate()
		let store = CardDataStore(
			retrievePayloads: { _ in .success([existingPayload]) },
			savePayload: { _, _, _ in true },
			deletePayload: { _, _ in true },
			beforeApplyingLoad: { await gate.waitBeforeCommit() }
		)

		let load = Task { @MainActor in
			await store.loadCards()
		}
		await gate.waitUntilReached()

		XCTAssertTrue(await store.addCard(newerCard))
		await gate.release()
		XCTAssertTrue(await load.value)

		XCTAssertEqual(store.findCard(by: existingCard.id), existingCard)
		XCTAssertEqual(store.findCard(by: newerCard.id), newerCard)
	}

	func testLateLoadDoesNotRestoreADeletedCard() async throws {
		let card = makeCard(id: UUID())
		let payload = try card.toData()
		let gate = LoadCommitGate()
		let store = CardDataStore(
			retrievePayloads: { _ in .success([payload]) },
			savePayload: { _, _, _ in true },
			deletePayload: { _, _ in true },
			beforeApplyingLoad: { await gate.waitBeforeCommit() }
		)

		XCTAssertTrue(await store.addCard(card))
		let load = Task { @MainActor in
			await store.loadCards()
		}
		await gate.waitUntilReached()

		XCTAssertTrue(await store.deleteCard(with: card.id))
		await gate.release()
		XCTAssertTrue(await load.value)

		XCTAssertNil(store.findCard(by: card.id))
	}

	func testOlderMutationCompletionCannotReplaceANewerMutation() async {
		let id = UUID()
		var olderCard = makeCard(id: id)
		olderCard.description = "Older"
		var newerCard = makeCard(id: id)
		newerCard.description = "Newer"
		let gate = MutationCommitGate(blockedSequence: 1)
		let store = CardDataStore(
			retrievePayloads: { _ in .empty },
			savePayload: { _, _, _ in true },
			deletePayload: { _, _ in true },
			beforeApplyingMutation: { await gate.waitBeforeCommit(sequence: $0) }
		)

		let olderMutation = Task { @MainActor in
			await store.addCard(olderCard)
		}
		await gate.waitUntilBlocked()

		XCTAssertTrue(await store.addCard(newerCard))
		await gate.release()
		XCTAssertTrue(await olderMutation.value)

		XCTAssertEqual(store.findCard(by: id), newerCard)
	}

	func testDecodeAllCardDataRecoversValidPayloads() throws {
		let valid = try JSONEncoder().encode(makeCard(id: UUID()))
		let invalid = Data("{}".utf8)

		XCTAssertNil(CardDataStore.decodeAllCardData(from: [nil]))
		XCTAssertNil(CardDataStore.decodeAllCardData(from: [invalid]))
		XCTAssertEqual(CardDataStore.decodeAllCardData(from: [])?.count, 0)

		let decoded = try XCTUnwrap(CardDataStore.decodeAllCardData(from: [valid, invalid, nil]))
		XCTAssertEqual(decoded.count, 1)
	}

	func testDebugFixturesSeedOnlyBeforeInitialization() {
		XCTAssertTrue(CardDataStore.shouldSeedDebugFixtures(
			isDebugOrSimulator: true,
			hasStoredCards: false,
			hasInitializedFixtures: false
		))
		XCTAssertFalse(CardDataStore.shouldSeedDebugFixtures(
			isDebugOrSimulator: true,
			hasStoredCards: false,
			hasInitializedFixtures: true
		))
	}

	private func makeCard(
		id: UUID,
		type: CardType = .creditCard,
		isArchived: Bool = false
	) -> CardData {
		CardData(
			id: id,
			number: "4111111111111111",
			cvv: "123",
			expiration: "12/30",
			name: "Test Card",
			description: "",
			type: type,
			network: .visa,
			isArchived: isArchived
		)
	}
}

private final class CardPayloadRetrievalStub: @unchecked Sendable {
	private let lock = NSLock()
	private var resultStorage: CardPayloadRetrievalResult

	init(result: CardPayloadRetrievalResult) {
		resultStorage = result
	}

	var result: CardPayloadRetrievalResult {
		get {
			lock.lock()
			defer { lock.unlock() }
			return resultStorage
		}
		set {
			lock.lock()
			resultStorage = newValue
			lock.unlock()
		}
	}
}

private final class KeychainOperationRecorder: @unchecked Sendable {
	enum Operation: Equatable {
		case retrieve
		case save
		case delete
	}

	private let lock = NSLock()
	private var operationsStorage: [Operation] = []
	private var ranOnMainThread = false

	func record(_ operation: Operation) {
		lock.lock()
		operationsStorage.append(operation)
		ranOnMainThread = ranOnMainThread || Thread.isMainThread
		lock.unlock()
	}

	var operations: [Operation] {
		lock.lock()
		defer { lock.unlock() }
		return operationsStorage
	}

	var allOperationsRanOffMainThread: Bool {
		lock.lock()
		defer { lock.unlock() }
		return !ranOnMainThread
	}
}

private actor LoadCommitGate {
	private var hasBeenReached = false
	private var reachedContinuation: CheckedContinuation<Void, Never>?
	private var releaseContinuation: CheckedContinuation<Void, Never>?

	func waitBeforeCommit() async {
		hasBeenReached = true
		reachedContinuation?.resume()
		reachedContinuation = nil
		await withCheckedContinuation { releaseContinuation = $0 }
	}

	func waitUntilReached() async {
		if hasBeenReached { return }
		await withCheckedContinuation { reachedContinuation = $0 }
	}

	func release() {
		releaseContinuation?.resume()
		releaseContinuation = nil
	}
}

private actor MutationCommitGate {
	private let blockedSequence: UInt64
	private var hasBlocked = false
	private var blockedContinuation: CheckedContinuation<Void, Never>?
	private var releaseContinuation: CheckedContinuation<Void, Never>?

	init(blockedSequence: UInt64) {
		self.blockedSequence = blockedSequence
	}

	func waitBeforeCommit(sequence: UInt64) async {
		guard sequence == blockedSequence else { return }
		hasBlocked = true
		blockedContinuation?.resume()
		blockedContinuation = nil
		await withCheckedContinuation { releaseContinuation = $0 }
	}

	func waitUntilBlocked() async {
		if hasBlocked { return }
		await withCheckedContinuation { blockedContinuation = $0 }
	}

	func release() {
		releaseContinuation?.resume()
		releaseContinuation = nil
	}
}
