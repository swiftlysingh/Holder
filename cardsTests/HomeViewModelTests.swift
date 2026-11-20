import XCTest
@testable import Holder

final class HomeViewModelTests: XCTestCase {
	@MainActor
	func testSelectingACardWhileAddingDoesNotNavigateUntilTheSheetDismisses() async {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let card = makeCard()

		model.isAddingCard = true
		model.selectCard(card)

		XCTAssertNil(model.selectedCard)
		XCTAssertTrue(model.isAddingCard)

		model.isAddingCard = false
		model.revealPendingCardSelection()

		XCTAssertEqual(model.selectedCard?.id, card.id)
	}

	@MainActor
	func testSelectingACardWhenTheAddSheetIsClosedNavigatesImmediately() async {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let card = makeCard()

		model.selectCard(card)

		XCTAssertEqual(model.selectedCard?.id, card.id)
	}

	@MainActor
	func testFinishingAddCardDefersDetailsUntilSheetDismissCompletes() async {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let card = makeCard()

		model.isAddingCard = true
		model.finishAddingCard(selecting: card)

		XCTAssertFalse(model.isAddingCard)
		XCTAssertNil(model.selectedCard, "card_details must not appear while the add-card sheet is still dismissing")

		model.revealPendingCardSelection()

		XCTAssertEqual(model.selectedCard?.id, card.id)
	}

	@MainActor
	func testDismissingTheAddSheetWithoutAPendingCardDoesNotChangeSelection() async {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let existing = makeCard()
		model.selectedCard = existing
		model.isAddingCard = true

		model.revealPendingCardSelection()

		XCTAssertEqual(model.selectedCard?.id, existing.id)
	}

	@MainActor
	func testFinishingAddCardReplacesAQueuedDeepLinkSelection() async {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let deepLinked = makeCard()
		let created = makeCard()

		model.isAddingCard = true
		model.selectCard(deepLinked)
		model.finishAddingCard(selecting: created)
		model.revealPendingCardSelection()

		XCTAssertEqual(model.selectedCard?.id, created.id)
	}

	@MainActor
	func testSelectionDuringSaveDismissalWaitsForOnDismiss() async {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let created = makeCard()
		let deepLinked = makeCard()
		model.isAddingCard = true
		model.finishAddingCard(selecting: created)

		model.selectCard(deepLinked)
		XCTAssertNil(model.selectedCard)
		model.revealPendingCardSelection()
		XCTAssertEqual(model.selectedCard?.id, deepLinked.id)

		model.selectedCard = nil
		model.revealPendingCardSelection()
		XCTAssertNil(model.selectedCard, "Dismissal must consume the pending selection")
	}

	@MainActor
	private func emptyCardStore() -> CardDataStore {
		CardDataStore(retrievePayloads: { _ in .empty })
	}

	@MainActor
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
