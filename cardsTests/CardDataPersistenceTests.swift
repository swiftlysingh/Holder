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

	func testDecodeAllCardDataFailsClosedOnAnyInvalidPayload() throws {
		let valid = try JSONEncoder().encode(makeCard(id: UUID()))
		let invalid = Data("{}".utf8)

		XCTAssertNil(CardDataStore.decodeAllCardData(from: [valid, invalid]))
		XCTAssertNil(CardDataStore.decodeAllCardData(from: [nil]))
		XCTAssertNil(CardDataStore.decodeAllCardData(from: [valid, nil]))
		XCTAssertEqual(CardDataStore.decodeAllCardData(from: [])?.count, 0)

		let decoded = try XCTUnwrap(CardDataStore.decodeAllCardData(from: [valid]))
		XCTAssertEqual(decoded.count, 1)
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
