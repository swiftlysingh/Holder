//
//  ContentView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI
import WhatsNewKit
import SinghDevKit

struct HomeView: View {
	@ObservedObject var model: HomeViewModel
	@Environment(\.analytics) private var analytics
	@Environment(\.sdk) private var sdk
	#if os(iOS)
	@State private var addCardSheetDetent: PresentationDetent = .fraction(0.25)
	#endif

	init(cardDataStore: CardDataStore = CardDataStore()) {
		self.model = HomeViewModel(cardDataStore: cardDataStore)
	}

	var body: some View {
		navigationContent
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
					model.cardDataStore.addCard(card)
				}))
			.id(card.id)
		}
		.sheet(isPresented: $model.isAddingCard) {
			let cardViewModel = CardViewModel(
				card: .init(id: UUID(),
						number: "",
						cvv: "",
						expiration: "",
						name: "",
						description: "",
						type: .creditCard
				   ),
				isEditing: true,
				addNewFlow: true,
				addUpdateCard: { card in
					// Keep the sheet open on failure so the entered form is preserved for retry.
					let succeeded = model.cardDataStore.addCard(card)
					if succeeded {
						model.isAddingCard = false
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
				[.fraction(0.25), .fraction(0.5), .large],
				selection: $addCardSheetDetent
			)
			.presentationDragIndicator(.visible)
			#endif
		}
		.sdkScreen(AppAnalyticsScreen.home)
	}

	private var navigationContent: some View {
		NavigationSplitView {
			sidebar
		} detail: {
			selectedCardDetail
		}
	}

	private var sidebar: some View {
		cardList
			.navigationTitle("Cards")
			.toolbarTitleDisplayMode(.inlineLarge)
			.task {
				model.cardDataStore.loadCards()
			}
			.toolbar {
				ToolbarItem {
					Button {
						track(.cardAddStarted)
						#if os(iOS)
						addCardSheetDetent = .fraction(0.25)
						#endif
						model.isAddingCard = true
					} label: {
						Label("Add Card", systemImage: "plus")
					}
				}
				#if !os(macOS)
				ToolbarItem(placement: .topBarTrailing) {
					NavigationLink(
						destination: sdk.settingsView()
							.sdkScreen(AppAnalyticsScreen.settings)
							.toolbarTitleDisplayMode(.inlineLarge)
					) {
						Image(systemName: "gear")
					}
				}
				#endif
			}
			.alert("Enable Biometrics",isPresented: model.$isFirstLaunch, actions: {
				Button("Yes", role: .cancel) {
					UserSettings.shared.isAuthEnabled = true
				}
				Button("No", role: .destructive) {
					UserSettings.shared.isAuthEnabled = false
				}
			})
		}

	private var cardList: some View {
		List(selection: $model.selectedCard) {
			ForEach(CardType.allCases) { type in
				cardSection(for: type)
			}
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
	}

	private func cardSection(for type: CardType) -> some View {
		Section(header: Text("\(type.rawValue)s")) {
			ForEach(model.cardDataStore.cardsByType[type] ?? [], id: \.id) { card in
				cardRow(withActionsFor: card)
			}
		}
	}

	@ViewBuilder
	private var selectedCardDetail: some View {
		if let card = model.selectedCard {
			CardView(model: CardViewModel(
				card: card,
				addUpdateCard: { card in
					model.cardDataStore.addCard(card)
				}))
			.id(card.id)
		} else {
			Text("Tap on a Card to view details")
		}
	}

	private func deleteCard(_ card: CardData) {
		let event: AppAnalyticsEvent = model.cardDataStore.deleteCard(with: card.id)
			? .cardDeleted(location: .active)
			: .cardDeleteFailed(location: .active)
		track(event)
	}

	private func archiveCard(_ card: CardData) {
		let event: AppAnalyticsEvent = model.archiveCard(card)
			? .cardArchived
			: .cardArchiveFailed
		track(event)
	}

	private func track(_ event: AppAnalyticsEvent) {
		Task {
			await analytics.capture(event)
		}
	}

	private func cardRow(withActionsFor card: CardData) -> some View {
		getRowforCards(with: card)
			.swipeActions(edge: .trailing, allowsFullSwipe: false) {
				Button(role: .destructive) {
					deleteCard(card)
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
					deleteCard(card)
				} label: {
					Label("Delete", systemImage: "trash")
				}
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
					Text(card.number.toSecureCard())
				}
			}
		}
	}
}
