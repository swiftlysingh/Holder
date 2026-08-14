import XCTest
@testable import Holder

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
		XCTAssertNil(card.sortIndex)
		XCTAssertFalse(card.isFavorite)
		XCTAssertNil(card.palette)
		XCTAssertNil(card.hasLegacyImage)
	}

	func testCardDeckMetadataRoundTripsWithoutChangingSensitiveFields() throws {
		var card = makeCard(id: UUID())
		card.sortIndex = 7
		card.isFavorite = true

		let decoded = try JSONDecoder().decode(CardData.self, from: JSONEncoder().encode(card))

		XCTAssertEqual(decoded.sortIndex, 7)
		XCTAssertTrue(decoded.isFavorite)
		XCTAssertEqual(decoded.number, card.number)
		XCTAssertEqual(decoded.cvv, card.cvv)
	}

	func testCardOrderingPrefersFavoritesThenPersistedIndexThenStableLegacyID() {
		var favorite = makeCard(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!)
		favorite.isFavorite = true
		favorite.sortIndex = 99

		var firstManual = makeCard(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!)
		firstManual.sortIndex = 2
		var secondManual = makeCard(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
		secondManual.sortIndex = 8
		let firstLegacy = makeCard(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
		let secondLegacy = makeCard(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)

		let ordered = CardDataStore.deckOrdered([
			secondLegacy,
			secondManual,
			favorite,
			firstLegacy,
			firstManual
		])

		XCTAssertEqual(
			ordered.map(\.id),
			[favorite.id, firstManual.id, secondManual.id, firstLegacy.id, secondLegacy.id]
		)
	}

	func testLoyaltyCardPaletteRoundTripPreservesExistingCardFields() throws {
		let card = CardData(
			id: UUID(),
			number: "12345678",
			cvv: "",
			expiration: "",
			name: "Rema",
			description: "Rema 1000",
			type: .loyaltyCard,
			network: .other,
			palette: .forest
		)

		let decoded = try JSONDecoder().decode(CardData.self, from: JSONEncoder().encode(card))

		XCTAssertEqual(decoded.type, .loyaltyCard)
		XCTAssertEqual(decoded.palette, .forest)
		XCTAssertEqual(decoded.number, "1234 5678")
	}

	func testTravelCardRoundTripPreservesType() throws {
		let card = CardData(
			id: UUID(),
			number: "992441",
			cvv: "",
			expiration: "",
			name: "",
			description: "SAS EuroBonus",
			type: .travelCard,
			network: .other,
			palette: .berry
		)

		let decoded = try JSONDecoder().decode(CardData.self, from: JSONEncoder().encode(card))

		XCTAssertEqual(decoded.type, .travelCard)
		XCTAssertEqual(decoded.palette, .berry)
		XCTAssertEqual(decoded.number, "9924 41")
	}

	func testKnownLegacyImageAbsenceRoundTripsForNewCards() throws {
		var card = makeCard(id: UUID(), type: .otherCard)
		card.hasLegacyImage = false

		let decoded = try JSONDecoder().decode(CardData.self, from: JSONEncoder().encode(card))

		XCTAssertEqual(decoded.hasLegacyImage, false)
	}

	func testLegacyOtherCardRawValueRemainsAvailableForExplicitMigration() throws {
		let data = try JSONSerialization.data(withJSONObject: [
			"id": UUID().uuidString,
			"number": "",
			"cvv": "",
			"expiration": "",
			"name": "Legacy image card",
			"description": "",
			"type": CardType.otherCard.rawValue
		])

		let card = try JSONDecoder().decode(CardData.self, from: data)

		XCTAssertEqual(card.type, .otherCard)
		XCTAssertEqual(card.type.rawValue, "Other Card")
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

	func testLoadCardsReportsFailureAndPreservesExistingCards() {
		let card = makeCard(id: UUID())
		let stub = CardRetrievalStub(result: .success([card]))
		let store = CardDataStore(retrieveCards: { _ in stub.result })

		XCTAssertEqual(store.findCard(by: card.id), card)

		stub.result = .failure
		XCTAssertFalse(store.loadCards())
		XCTAssertEqual(store.findCard(by: card.id), card)

		stub.result = .empty
		XCTAssertTrue(store.loadCards())
		// Sample/debug cards use fresh UUIDs, so the previously stubbed id must not resolve.
		XCTAssertNil(store.findCard(by: card.id))
	}

	func testFailedCardFavoriteSaveDoesNotMutateInMemoryState() {
		let card = makeCard(id: UUID())
		let store = CardDataStore(
			retrieveCards: { _ in .success([card]) },
			saveStoredCard: { _ in false }
		)

		XCTAssertFalse(store.setFavorite(cardID: card.id, isFavorite: true))
		XCTAssertFalse(store.findCard(by: card.id)?.isFavorite ?? true)
		XCTAssertEqual(store.lastError, .persistenceFailed)
	}

	func testFailedCardDeckReorderExposesOnlyPersistedPrefix() {
		let first = makeCard(id: UUID())
		let second = makeCard(id: UUID())
		var saveCount = 0
		let store = CardDataStore(
			retrieveCards: { _ in .success([first, second]) },
			saveStoredCard: { _ in
				saveCount += 1
				return saveCount != 2
			}
		)

		var firstReordered = first
		firstReordered.sortIndex = 1
		var secondReordered = second
		secondReordered.sortIndex = 0

		XCTAssertFalse(store.updateDeckOrder([firstReordered, secondReordered]))
		XCTAssertEqual(store.findCard(by: first.id)?.sortIndex, 1)
		XCTAssertNil(store.findCard(by: second.id)?.sortIndex)
		XCTAssertEqual(store.lastError, .persistenceFailed)
	}

	func testArchivedCardCanBeFoundForDeletionAndDeepLinkRecovery() {
		let archivedCard = makeCard(id: UUID(), type: .otherCard, isArchived: true)
		let store = CardDataStore(
			retrieveCards: { _ in .success([archivedCard]) },
			deleteStoredCard: { _ in true },
			deleteLegacyImage: { _ in true }
		)

		XCTAssertEqual(store.findCard(by: archivedCard.id), archivedCard)
	}

	func testOtherCardDeletionKeepsRetryableRecordWhenLegacyImageDeletionFails() {
		let card = makeCard(id: UUID(), type: .otherCard)
		var metadataDeleteCount = 0
		let store = CardDataStore(
			retrieveCards: { _ in .success([card]) },
			deleteStoredCard: { _ in
				metadataDeleteCount += 1
				return true
			},
			deleteLegacyImage: { _ in false }
		)

		XCTAssertFalse(store.deleteCard(with: card.id))
		XCTAssertEqual(metadataDeleteCount, 0)
		XCTAssertEqual(store.findCard(by: card.id), card)
	}

	func testOtherCardDeletionRemovesMetadataOnlyAfterLegacyImage() {
		let card = makeCard(id: UUID(), type: .otherCard)
		var operations: [String] = []
		let store = CardDataStore(
			retrieveCards: { _ in .success([card]) },
			deleteStoredCard: { _ in
				operations.append("metadata")
				return true
			},
			deleteLegacyImage: { _ in
				operations.append("image")
				return true
			}
		)

		XCTAssertTrue(store.deleteCard(with: card.id))
		XCTAssertEqual(operations, ["image", "metadata"])
		XCTAssertNil(store.findCard(by: card.id))
	}

	func testMetadataDeletionFailureRestoresVisibleCardForRetry() {
		let card = makeCard(id: UUID())
		let store = CardDataStore(
			retrieveCards: { _ in .success([card]) },
			deleteStoredCard: { _ in false },
			deleteLegacyImage: { _ in true }
		)

		XCTAssertFalse(store.deleteCard(with: card.id))
		XCTAssertEqual(store.findCard(by: card.id), card)
		XCTAssertEqual(store.lastError, .persistenceFailed)
	}

	func testPaymentCardDeletionDoesNotTouchLegacyImageStore() {
		let card = makeCard(id: UUID())
		var legacyImageDeleteCount = 0
		let store = CardDataStore(
			retrieveCards: { _ in .success([card]) },
			deleteStoredCard: { _ in true },
			deleteLegacyImage: { _ in
				legacyImageDeleteCount += 1
				return true
			}
		)

		XCTAssertTrue(store.deleteCard(with: card.id))
		XCTAssertEqual(legacyImageDeleteCount, 0)
	}

	func testInterruptedLegacyImageMarkerOnPaymentCardDeletesImageFirst() {
		var card = makeCard(id: UUID())
		card.hasLegacyImage = true
		var operations: [String] = []
		let store = CardDataStore(
			retrieveCards: { _ in .success([card]) },
			deleteStoredCard: { _ in
				operations.append("metadata")
				return true
			},
			deleteLegacyImage: { _ in
				operations.append("image")
				return true
			}
		)

		XCTAssertTrue(store.deleteCard(with: card.id))
		XCTAssertEqual(operations, ["image", "metadata"])
		XCTAssertNil(store.findCard(by: card.id))
	}

	func testKnownImageFreeOtherCardDeletesWithoutRequiringICloud() {
		var card = makeCard(id: UUID(), type: .otherCard)
		card.hasLegacyImage = false
		var legacyImageDeleteCount = 0
		let store = CardDataStore(
			retrieveCards: { _ in .success([card]) },
			deleteStoredCard: { _ in true },
			deleteLegacyImage: { _ in
				legacyImageDeleteCount += 1
				return false
			}
		)

		XCTAssertTrue(store.deleteCard(with: card.id))
		XCTAssertEqual(legacyImageDeleteCount, 0)
		XCTAssertNil(store.findCard(by: card.id))
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

private final class CardRetrievalStub {
	var result: CardDataStore.CardRetrievalResult

	init(result: CardDataStore.CardRetrievalResult) {
		self.result = result
	}
}
