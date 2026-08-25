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
			"type": "Credit Card"
		])

		let card = try JSONDecoder().decode(CardData.self, from: data)

		XCTAssertEqual(card.id, id)
		XCTAssertEqual(card.network, .visa)
		XCTAssertFalse(card.isArchived)
	}

	func testPartitionSeparatesActiveAndArchivedCards() {
		let creditCard = makeCard(id: UUID())
		let debitCard = makeCard(id: UUID(), type: .debit)
		let archivedCard = makeCard(id: UUID(), type: .other, isArchived: true)

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

		let initialLoadSucceeded = await store.loadCards()
		XCTAssertTrue(initialLoadSucceeded)
		XCTAssertEqual(store.findCard(by: card.id), card)

		stub.result = .failure
		let failedLoadSucceeded = await store.loadCards()
		XCTAssertFalse(failedLoadSucceeded)
		XCTAssertEqual(store.findCard(by: card.id), card)

		stub.result = .empty
		let emptyLoadSucceeded = await store.loadCards()
		XCTAssertTrue(emptyLoadSucceeded)
		// Sample/debug cards use fresh UUIDs, so the previously stubbed id must not resolve.
		XCTAssertNil(store.findCard(by: card.id))
	}

	func testKeychainReadsWritesAndDeletesRunOffTheMainThread() async throws {
		let storedCard = makeCard(id: UUID())
		let newCard = makeCard(id: UUID())
		let storedPayload = try storedCard.toData()
		let store = CardDataStore(
			retrievePayloads: { _ in
				XCTAssertFalse(Thread.isMainThread)
				return .success([storedPayload])
			},
			savePayload: { _, _, _ in
				XCTAssertFalse(Thread.isMainThread)
				return true
			},
			deletePayload: { _, _ in
				XCTAssertFalse(Thread.isMainThread)
				return true
			}
		)

		let loadSucceeded = await store.loadCards()
		let saveSucceeded = await store.addCard(newCard)
		let deleteSucceeded = await store.deleteCard(with: storedCard.id)
		XCTAssertTrue(loadSucceeded)
		XCTAssertTrue(saveSucceeded)
		XCTAssertTrue(deleteSucceeded)
	}

	func testLoadingExistingCardsDoesNotWriteOrDelete() async throws {
		let card = makeCard(id: UUID())
		let recorder = MutationCallRecorder()
		let store = CardDataStore(
			retrievePayloads: { _ in .success([try? card.toData()]) },
			savePayload: { _, _, _ in
				recorder.recordSave()
				return true
			},
			deletePayload: { _, _ in
				recorder.recordDelete()
				return true
			}
		)

		let didLoad = await store.loadCards()
		XCTAssertTrue(didLoad)
		XCTAssertEqual(store.findCard(by: card.id), card)
		XCTAssertEqual(recorder.saveCount, 0)
		XCTAssertEqual(recorder.deleteCount, 0)
	}

	func testSuccessfulSaveDoesNotDependOnFollowingReload() async throws {
		let existingCard = makeCard(id: UUID())
		let newCard = makeCard(id: UUID(), type: .debit)
		let stub = CardPayloadRetrievalStub(result: .success([try existingCard.toData()]))
		let store = CardDataStore(
			retrievePayloads: { _ in stub.result },
			savePayload: { _, _, _ in
				stub.result = .failure
				return true
			},
			deletePayload: { _, _ in false }
		)

		let didLoad = await store.loadCards()
		let didAdd = await store.addCard(newCard)
		XCTAssertTrue(didLoad)
		XCTAssertTrue(didAdd)
		XCTAssertEqual(store.findCard(by: existingCard.id), existingCard)
		XCTAssertEqual(store.findCard(by: newCard.id), newCard)

		let didReload = await store.loadCards()
		XCTAssertFalse(didReload)
		XCTAssertEqual(store.findCard(by: existingCard.id), existingCard)
		XCTAssertEqual(store.findCard(by: newCard.id), newCard)
	}

	func testLateLoadMergesNewerMutationWithoutHidingExistingCards() async throws {
		let existingCard = makeCard(id: UUID())
		let newerCard = makeCard(id: UUID())
		let existingPayload = try existingCard.toData()
		let gate = LoadCommitGate()
		let stub = CardPayloadRetrievalStub(result: .success([existingPayload]))
		let store = CardDataStore(
			retrievePayloads: { _ in stub.result },
			savePayload: { data, _, _ in
				stub.result = .success([existingPayload, data])
				return true
			},
			deletePayload: { _, _ in true },
			beforeApplyingLoad: { await gate.waitBeforeCommit() }
		)

		let load = Task { @MainActor in
			await store.loadCards()
		}
		await gate.waitUntilReached()

		let saveSucceeded = await store.addCard(newerCard)
		XCTAssertTrue(saveSucceeded)
		await gate.release()
		let loadSucceeded = await load.value
		XCTAssertTrue(loadSucceeded)

		XCTAssertEqual(store.findCard(by: existingCard.id), existingCard)
		XCTAssertEqual(store.findCard(by: newerCard.id), newerCard)
	}

	func testLateLoadDoesNotRestoreADeletedCard() async throws {
		let card = makeCard(id: UUID())
		let payload = try card.toData()
		let gate = LoadCommitGate()
		let stub = CardPayloadRetrievalStub(result: .success([payload]))
		let store = CardDataStore(
			retrievePayloads: { _ in stub.result },
			savePayload: { _, _, _ in true },
			deletePayload: { _, _ in
				stub.result = .empty
				return true
			},
			beforeApplyingLoad: { await gate.waitBeforeCommit() }
		)

		let load = Task { @MainActor in
			await store.loadCards()
		}
		await gate.waitUntilReached()

		let deleteSucceeded = await store.deleteCard(with: card.id)
		XCTAssertTrue(deleteSucceeded)
		await gate.release()
		let loadSucceeded = await load.value
		XCTAssertTrue(loadSucceeded)

		XCTAssertNil(store.findCard(by: card.id))
	}

	func testDeletingOtherCardKeepsImageWhenKeychainDeleteFails() async throws {
		let card = makeCard(id: UUID(), type: .other)
		let payload = try card.toData()
		let stub = CardPayloadRetrievalStub(result: .success([payload]))
		let imageStore = TestCardImageStore(deleteResults: [])
		let store = CardDataStore(
			retrievePayloads: { _ in stub.result },
			savePayload: { _, _, _ in true },
			deletePayload: { _, _ in false },
			imageStore: imageStore
		)

		let didLoad = await store.loadCards()
		let didDelete = await store.deleteCard(with: card.id)
		let deletedImageIDs = await imageStore.deletedIDs
		XCTAssertTrue(didLoad)
		XCTAssertFalse(didDelete)
		XCTAssertEqual(store.findCard(by: card.id), card)
		XCTAssertTrue(deletedImageIDs.isEmpty)
	}

	func testDeletingCardAttemptsImageCleanupRegardlessOfCurrentType() async throws {
		let card = makeCard(id: UUID())
		let stub = CardPayloadRetrievalStub(result: .success([try card.toData()]))
		let imageStore = TestCardImageStore(deleteResults: [false])
		let store = CardDataStore(
			retrievePayloads: { _ in stub.result },
			savePayload: { _, _, _ in true },
			deletePayload: { _, _ in
				stub.result = .empty
				return true
			},
			imageStore: imageStore
		)

		let didLoad = await store.loadCards()
		let didDelete = await store.deleteCard(with: card.id)
		let deletedImageIDs = await imageStore.deletedIDs
		XCTAssertTrue(didLoad)
		XCTAssertTrue(didDelete)
		XCTAssertNil(store.findCard(by: card.id))
		XCTAssertEqual(deletedImageIDs, [card.id])
	}

	func testQueuedUpdateDoesNotRestoreDeletedCard() async throws {
		let card = makeCard(id: UUID())
		let persistence = BlockingDeletePersistence(payload: try card.toData())
		let store = CardDataStore(
			retrievePayloads: { _ in persistence.retrieve() },
			savePayload: { data, _, _ in persistence.save(data) },
			deletePayload: { _, _ in persistence.delete() }
		)

		let didLoad = await store.loadCards()
		XCTAssertTrue(didLoad)
		let delete = Task { @MainActor in await store.deleteCard(with: card.id) }
		await persistence.waitUntilDeleteStarts()
		let update = Task { @MainActor in await store.updateCard(card) }
		persistence.allowDeleteToFinish()

		let didDelete = await delete.value
		let didUpdate = await update.value
		XCTAssertTrue(didDelete)
		XCTAssertFalse(didUpdate)
		XCTAssertNil(store.findCard(by: card.id))
		XCTAssertEqual(persistence.saveCount, 0)
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
		type: CardType = .credit,
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
		get { lock.withLock { resultStorage } }
		set { lock.withLock { resultStorage = newValue } }
	}
}

private actor TestCardImageStore: CardImageStore {
	private(set) var deletedIDs: [UUID] = []
	private var deleteResults: [Bool]

	init(deleteResults: [Bool]) {
		self.deleteResults = deleteResults
	}

	func loadImageData(for uuid: UUID) async -> Data? { nil }
	func saveImageData(_ data: Data, for uuid: UUID) async -> Bool { true }
	func deleteImage(for uuid: UUID) async -> Bool {
		deletedIDs.append(uuid)
		return deleteResults.isEmpty ? true : deleteResults.removeFirst()
	}
}

private final class MutationCallRecorder: @unchecked Sendable {
	private let lock = NSLock()
	private var saves = 0
	private var deletes = 0

	func recordSave() {
		lock.withLock { saves += 1 }
	}

	func recordDelete() {
		lock.withLock { deletes += 1 }
	}

	var saveCount: Int { lock.withLock { saves } }
	var deleteCount: Int { lock.withLock { deletes } }
}

private final class BlockingDeletePersistence: @unchecked Sendable {
	private let lock = NSLock()
	private let deleteStarted = DispatchGroup()
	private let finishDelete = DispatchSemaphore(value: 0)
	private var payload: Data?
	private var saves = 0

	init(payload: Data) {
		self.payload = payload
		deleteStarted.enter()
	}

	func retrieve() -> CardPayloadRetrievalResult {
		lock.withLock {
			payload.map { .success([$0]) } ?? .empty
		}
	}

	func save(_ data: Data) -> Bool {
		lock.withLock {
			saves += 1
			payload = data
		}
		return true
	}

	func delete() -> Bool {
		deleteStarted.leave()
		finishDelete.wait()
		lock.withLock { payload = nil }
		return true
	}

	func waitUntilDeleteStarts() async {
		await withCheckedContinuation { continuation in
			deleteStarted.notify(queue: .global(qos: .userInitiated)) {
				continuation.resume()
			}
		}
	}

	func allowDeleteToFinish() {
		finishDelete.signal()
	}

	var saveCount: Int { lock.withLock { saves } }
}

private actor LoadCommitGate {
	private var hasBeenReached = false
	private var reachedContinuation: CheckedContinuation<Void, Never>?
	private var releaseContinuation: CheckedContinuation<Void, Never>?

	func waitBeforeCommit() async {
		guard !hasBeenReached else { return }
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
