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
    
    var appName: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    }

	var body: some View {
		NavigationStack {
			List{
				ForEach(CardType.allCases){ type in
					Section(header: Text("\(type.rawValue)s")){
						ForEach(cardDataStore.cardsByType[type] ?? [], id: \.id) { card in
							NavigationLink(destination:
											CardView(card: card,
													 addUpdateCard:
														{ card in
								cardDataStore.addCard(card)
							})){
								VStack(alignment: .leading){
									Text(card.name)
									Text(card.number.toSecureCard())
								}
							}
						}
						.onDelete { offsets in
							deleteCard(at: offsets, inSection: type)
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
														 name: "",
                                                         description: "",
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
	private func deleteCard(at offsets: IndexSet, inSection cardType: CardType) {
		offsets.forEach { index in
			guard let card = cardDataStore.cardsByType[cardType]?[index] else { return }
			if cardDataStore.deleteCard(with: card.id) {
				cardDataStore.cardsByType[cardType]?.remove(at: index)
			} else {
				// Handle error if deletion was not successful
			}
		}
	}
}

#Preview {
	HomeView()
}
