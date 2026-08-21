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

	init(cardDataStore: CardDataStore = CardDataStore()) {
		self.model = HomeViewModel(cardDataStore: cardDataStore)
	}

	var body: some View {
		NavigationSplitView {
			List(selection: $model.selectedCard) {
				ForEach(CardType.allCases) { type in
					Section(header: Text("\(type.rawValue)s")){
						ForEach(model.cardDataStore.cardsByType[type] ?? [], id: \.id) { card in
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
						Button("Add a new \(type.rawValue)") {
							track(.cardAddStarted)
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
				await model.cardDataStore.loadCardsAsync()
			}
			#if !os(macOS)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					NavigationLink(
						destination: sdk.settingsView()
							.sdkScreen(AppAnalyticsScreen.settings)
							.toolbarTitleDisplayMode(.inlineLarge)
					) {
						Image(systemName: "gear")
					}
				}
			}
			#endif
			.alert("Enable Biometrics",isPresented: model.$isFirstLaunch, actions: {
				Button("Yes", role: .cancel) { 
					UserSettings.shared.isAuthEnabled = true
				}
				Button("No", role: .destructive) { 
					UserSettings.shared.isAuthEnabled = false
				}
			})
		} detail: {
			if let card = model.selectedCard {
				CardView(model: CardViewModel(
								card: card,
								addUpdateCard: { card in
									model.cardDataStore.addCard(card)
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
					model.cardDataStore.addCard(card)
				}))
			.id(card.id)
		}
		.sheet(item: $model.addingType) { type in
			NavigationView {
				CardView(model: CardViewModel(
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
						let succeeded = model.cardDataStore.addCard(card)
						if succeeded {
							model.addingType = nil
						}
						return succeeded
					})
				)
			}
		}
		.sdkScreen(AppAnalyticsScreen.home)
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
