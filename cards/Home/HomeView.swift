//
//  ContentView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI
import WhatsNewKit

struct HomeView: View {

	@ObservedObject var model = HomeViewModel()

	var body: some View {
		NavigationSplitView {
			List(){
				ForEach(CardType.allCases){ type in
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
									})
								)
							}
						}
					}
				}
			}
			.navigationTitle("Cards")
			.toolbar{
				NavigationLink(destination: SettingsView()){
					Image(systemName: "gear")
				}
			}
		} detail: {
		Text("Tap on a Card to view details")
		}
		.whatsNewSheet()
	}

	private func getRowforCards(with card: CardData) -> some View {
		
		NavigationLink(destination: CardView(model:
												CardViewModel(
													card: card,
													addUpdateCard: { card in
														model.cardDataStore.addCard(card)
													}
												)
											)
		) {
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
