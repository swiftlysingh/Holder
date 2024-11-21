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

	@ObservedObject var model = HomeViewModel()

	var body: some View {
		NavigationSplitView {
			List(CardType.allCases, selection: $model.selectedCard){ type in
					Section(header: Text("\(type.rawValue)s")){
						ForEach(model.cardDataStore.cardsByType[type] ?? [], id: \.id) { card in
							getRowforCards(with: card)
						}
						.onDelete { offsets in
							model.deleteCard(at: offsets, inSection: type)
						}
						Button("Add a new \(type.rawValue)") {
							model.showingPopover.toggle()
						}
						.sheet(isPresented: $model.showingPopover) {
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
										model.showingPopover = false
										model.cardDataStore.loadCards()
									})
								)
							}
						}
					}
				}
			.navigationTitle("Cards")
			.onAppear {
				model.cardDataStore.loadCards()
			}
			.toolbar{
                NavigationLink(destination: SettingsView(model: SettingsViewModel())){
					Image(systemName: "gear")
				}
			}
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
	}

	private func getRowforCards(with card: CardData) -> some View {
		NavigationLink(value: card) {
			HStack {
			  if let customSymbol = card.customSymbol, !customSymbol.isEmpty {
					Image(systemName: "car")
						.resizable()
						.scaledToFit()
						.frame(width: 36, height: 36)
						.foregroundColor(.accentColor)
				} else {
					Image(card.network.rawValue)
						.resizable()
						.scaledToFit()
						.frame(width: 36, height: 36)
				}

				VStack(alignment: .leading) {
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
