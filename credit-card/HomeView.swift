//
//  ContentView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI

struct HomeView: View {

	@Bindable var cardDataStore = CardDataStore()

	@State private var showingPopover = false

	var body: some View {
		NavigationStack {
			List{
				ForEach(CardType.allCases){ type in
					Section(header: Text("\(type.rawValue)s")){
						ForEach(cardDataStore.cards.filter({ cardData in
							cardData.type == type
						})) { card in
							NavigationLink(destination: 
											CardView(card: card,
													 addUpdateCard:
														{ card in
								cardDataStore.addCard(card)
							})){
								VStack(alignment: .leading){
									Text(card.nickname)
									Text(card.number.toSecureCard())
								}
							}
						}
						Button("Add a new \(type.rawValue)") {
							showingPopover.toggle()
						}
						.sheet(isPresented: $showingPopover) {
							NavigationView {
								CardView(card: .init(id: UUID(),
													 number: "",
													 cvv: "",
													 expiration: "",
													 nickname: "",
													 type: type),
										 isEditing: true,
										 addUpdateCard: { card in
									cardDataStore.addCard(card)
									showingPopover = false
								}
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
		}
	}
}

#Preview {
	HomeView()
}
