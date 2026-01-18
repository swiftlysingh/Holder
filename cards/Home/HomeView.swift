//
//  ContentView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI
import WhatsNewKit
import Settings

struct HomeView: View {
	@ObservedObject var model: HomeViewModel

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
										_ = model.cardDataStore.deleteCard(with: card.id)
										model.cardDataStore.cardsByType[type]?.removeAll { $0.id == card.id }
									} label: {
										Label("Delete", systemImage: "trash")
									}
									Button {
										model.archiveCard(card)
									} label: {
										Label("Archive", systemImage: "archivebox")
									}
									.tint(.orange)
								}
						}
						Button("Add a new \(type.rawValue)") {
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
			.task {
				model.cardDataStore.loadCards()
			}
			#if !os(macOS)
			.toolbar {
				NavigationLink(destination: SettingsView(model: SettingsViewModel())) {
					Image(systemName: "gear")
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
			} 
			else {
				Text("Tap on a Card to view details")
			}
		}
		.whatsNewSheet()
		.onOpenURL { url in
			model.handleDeepLink(url)
		}
		.navigationDestination(item: $model.selectedCard) { card in
			CardView(model: CardViewModel(
				card: card,
				addUpdateCard: { card in
					model.cardDataStore.addCard(card)
				}))
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
						model.cardDataStore.addCard(card)
						model.addingType = nil
						Task { @MainActor in
							model.cardDataStore.loadCards()
						}
					})
				)
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
