//
//  ContentView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI
import WhatsNewKit
import SinghDevKit

@MainActor
struct HomeView: View {
	@ObservedObject private var model: HomeViewModel
	@EnvironmentObject private var authenticationSession: AuthenticationSession
	@Environment(\.analytics) private var analytics
	@Environment(\.sdk) private var sdk
	@State private var cardPendingDeletion: CardData?
	#if !os(macOS)
	@State private var isShowingSettings = false
	#endif
	#if os(iOS)
	@State private var addCardSheetDetent: PresentationDetent = .fraction(0.5)
	#endif

	init(model: HomeViewModel) {
		self.model = model
	}

	var body: some View {
		NavigationSplitView {
			List(selection: $model.selectedCard) {
				ForEach(CardType.allCases) { type in
					Section(header: Text(type.rawValue)){
						ForEach(model.cardDataStore.cardsByType[type] ?? [], id: \.id) { card in
							getRowforCards(with: card)
								.swipeActions(edge: .trailing, allowsFullSwipe: false) {
									Button(role: .destructive) {
										cardPendingDeletion = card
									} label: {
										Label("Delete", systemImage: "trash")
									}
									Button {
										archiveCard(card)
									} label: {
										Label("Archive", systemImage: "archivebox")
									}
									.tint(.orange)
								}
								.contextMenu {
									Button {
										archiveCard(card)
									} label: {
										Label("Archive", systemImage: "archivebox")
									}
									Button(role: .destructive) {
										cardPendingDeletion = card
									} label: {
										Label("Delete", systemImage: "trash")
									}
								}
						}
						Button("Add a new card") {
							track(.cardAddStarted)
							#if os(iOS)
							addCardSheetDetent = .fraction(0.5)
							#endif
							model.addingType = type
						}
					}
				}
				// Archived Cards Link
				if !model.cardDataStore.archivedCards.isEmpty {
					Section {
						NavigationLink {
							ArchivedCardsView(model: model)
						} label: {
							HStack {
								Image(systemName: "archivebox")
								Text("View Archived Cards (\(model.cardDataStore.archivedCards.count))")
							}
						}
					}
				}
			}
			.navigationTitle("Cards")
			.toolbarTitleDisplayMode(.inlineLarge)
			.task {
				await model.cardDataStore.loadCards()
			}
			#if !os(macOS)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						isShowingSettings = true
					} label: {
						Image(systemName: "gear")
					}
				}
			}
			#endif
		} detail: {
			if let card = model.selectedCard {
				CardView(model: CardViewModel(
								card: card,
								addUpdateCard: { card in
									await model.cardDataStore.updateCard(card)
								}))
					.id(card.id)
			} 
			else {
				Text("Tap on a Card to view details")
			}
		}
		.whatsNewSheet()
		.onOpenURL { url in
			model.handleDeepLink(url, onOpenedFromWidget: {
				track(.cardOpenedFromWidget)
			})
		}
		.navigationDestination(item: $model.selectedCard) { card in
			CardView(model: CardViewModel(
				card: card,
				addUpdateCard: { card in
					await model.cardDataStore.updateCard(card)
				}))
			.id(card.id)
		}
		.sheet(item: $model.addingType) { type in
			let cardViewModel = CardViewModel(
				card: .init(id: UUID(),
						number: "",
						cvv: "",
						expiration: "",
						name: "",
						description: "",
						type: type
				   ),
				isEditing: true,
				addNewFlow: true,
				addUpdateCard: { card in
					// Keep the sheet open on failure so the entered form is preserved for retry.
					let succeeded = await model.cardDataStore.addCard(card)
					if succeeded {
						model.addingType = nil
					}
					return succeeded
				}
			)
			NavigationView {
				#if os(iOS)
				CardView(
					model: cardViewModel,
					cardSheetDetent: $addCardSheetDetent
				)
				#else
				CardView(model: cardViewModel)
				#endif
			}
			#if os(iOS)
			.presentationDetents(
				[.fraction(0.5), .large],
				selection: $addCardSheetDetent
			)
			.presentationDragIndicator(.visible)
			#endif
		}
		.confirmationDialog(
			"Delete this card?",
			isPresented: Binding(
				get: { cardPendingDeletion != nil },
				set: { if !$0 { cardPendingDeletion = nil } }
			),
			presenting: cardPendingDeletion
		) { card in
			Button("Delete Card", role: .destructive) {
				authenticateAndDelete(card)
			}
		} message: { _ in
			Text("This cannot be undone.")
		}
		#if !os(macOS)
		.sheet(isPresented: $isShowingSettings) {
			NavigationStack {
				sdk.settingsView()
					.sdkScreen(AppAnalyticsScreen.settings)
					.toolbar {
						ToolbarItem(placement: .confirmationAction) {
							Button("Done") {
								isShowingSettings = false
							}
						}
					}
			}
		}
		#endif
		.sdkScreen(AppAnalyticsScreen.home)
	}

	private func deleteCard(_ card: CardData) {
		Task { @MainActor in
			let event: AppAnalyticsEvent = await model.cardDataStore.deleteCard(with: card.id)
				? .cardDeleted(location: .active)
				: .cardDeleteFailed(location: .active)
			track(event)
		}
	}

	private func authenticateAndDelete(_ card: CardData) {
		authenticationSession.authenticateForSensitiveAccess(
			reason: "Authenticate to delete this card."
		) { success in
			guard success else { return }
			deleteCard(card)
			cardPendingDeletion = nil
		}
	}

	private func archiveCard(_ card: CardData) {
		Task { @MainActor in
			let event: AppAnalyticsEvent = await model.cardDataStore.archiveCard(card)
				? .cardArchived
				: .cardArchiveFailed
			track(event)
		}
	}

	private func track(_ event: AppAnalyticsEvent) {
		Task {
			await analytics.capture(event)
		}
	}

	private func getRowforCards(with card: CardData) -> some View {
		NavigationLink(value: card){
			HStack{
				Image(card.network.rawValue)
					.resizable()
					.scaledToFit()
					.frame(width: 36,height: 36)

				VStack(alignment: .leading){
					if card.description != "" {
						Text(card.description)
					} else {
						Text(card.name)
					}
					Text(card.number.maskedCardNumber())
				}
			}
		}
	}
}
