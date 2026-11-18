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

		model.isAddingCard = false
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
		XCTAssertNil(model.selectedCard, "card_details must not appear while the add-card sheet is still dismissing")

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

	func testSelectionDuringSaveDismissalWaitsForOnDismiss() {
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

	func testTipWaitsForTheQualifyingSavedDetailsAndConsumesItsReturnOnce() {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let saved = makeCard()
		model.awaitSavedTipDetails(for: saved.id)

		XCTAssertFalse(model.consumeSavedTipDetailsReturn())
		model.savedTipDetailsDidAppear(for: UUID())
		XCTAssertFalse(model.consumeSavedTipDetailsReturn())

		model.savedTipDetailsDidAppear(for: saved.id)
		XCTAssertTrue(model.consumeSavedTipDetailsReturn())
		XCTAssertFalse(model.consumeSavedTipDetailsReturn())
	}

	func testTipReturnSurvivesSwitchingToAnotherCardBeforeTheList() {
		let model = HomeViewModel(cardDataStore: emptyCardStore())
		let saved = makeCard()
		model.awaitSavedTipDetails(for: saved.id)
		model.selectedCard = saved
		model.savedTipDetailsDidAppear(for: saved.id)

		let other = makeCard()
		model.selectedCard = other
		model.savedTipDetailsDidAppear(for: other.id)
		model.selectedCard = nil

		XCTAssertTrue(model.consumeSavedTipDetailsReturn())
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
