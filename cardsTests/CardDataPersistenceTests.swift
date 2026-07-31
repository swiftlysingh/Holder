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
