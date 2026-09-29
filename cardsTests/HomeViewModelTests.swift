import XCTest
@testable import Holder

@MainActor
final class HomeViewModelTests: XCTestCase {
	func testSelectingACardWhileAddingDoesNotNavigateUntilTheSheetDismisses() {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let card = makeCard()

		model.isAddingCard = true
		model.selectCard(card)

		XCTAssertNil(model.selectedCard)
		XCTAssertTrue(model.isAddingCard)

		model.revealPendingCardSelection()

		XCTAssertEqual(model.selectedCard?.id, card.id)
	}

	func testSelectingACardWhenTheAddSheetIsClosedNavigatesImmediately() {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let card = makeCard()

		model.selectCard(card)

		XCTAssertEqual(model.selectedCard?.id, card.id)
	}

	func testFinishingAddCardDefersDetailsUntilSheetDismissCompletes() {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let card = makeCard()

		model.isAddingCard = true
		model.finishAddingCard(selecting: card)

		XCTAssertFalse(model.isAddingCard)
		XCTAssertNil(model.selectedCard, "card_details must not appear while the zoom sheet is still dismissing")

		model.revealPendingCardSelection()

		XCTAssertEqual(model.selectedCard?.id, card.id)
	}

	func testDismissingTheAddSheetWithoutAPendingCardDoesNotChangeSelection() {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let existing = makeCard()
		model.selectedCard = existing
		model.isAddingCard = true

		model.revealPendingCardSelection()

		XCTAssertEqual(model.selectedCard?.id, existing.id)
	}

	func testFinishingAddCardReplacesAQueuedDeepLinkSelection() {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let deepLinked = makeCard()
		let created = makeCard()

		model.isAddingCard = true
		model.selectCard(deepLinked)
		model.finishAddingCard(selecting: created)
		model.revealPendingCardSelection()

		XCTAssertEqual(model.selectedCard?.id, created.id)
	}

	private func emptyCardStore() -> CardDataStore {
		CardDataStore(retrievePayloads: { _ in .empty })
	}

	private func makeCard() -> CardData {
		CardData(
			id: UUID(),
			number: "4111111111111111",
			cvv: "123",
			expiration: "12/30",
			name: "Test Card",
			description: "",
			type: .credit,
			network: .visa
		)
	}
}
