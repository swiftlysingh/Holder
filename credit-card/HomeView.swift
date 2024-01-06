//
//  ContentView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI
import SwiftData

struct HomeView: View {

	var cards : [PartCardData] = [
		PartCardData(card: CardData(id: UUID(), number: "2030 2020 3023 2323", cvv: "3232", expiration:"11/11", nickname: "Visa", type: .debitCard)),
								   PartCardData(card: CardData(id: UUID(), number: "2030 2020 3023 2323", cvv: "3232", expiration:"11/11", nickname: "Visa", type: .debitCard)),
							  
		PartCardData(card: CardData(id: UUID(), number: "2030 2020 3023 2323", cvv: "3232", expiration:"11/11", nickname: "Visa", type: .debitCard))
	]

//	@Query private var cards : [PartCardData]
	@Environment(\.modelContext) private var context

	var body: some View {
		NavigationStack {
			List{
				ForEach(CardType.allCases){ type in
					Section(header: Text("\(type.rawValue)s")){
						ForEach(cards.filter({ cardData in
							cardData.type == type
						})) { card in
							NavigationLink(destination: CardView(card: card,context)){
								VStack(alignment: .leading){
									Text(card.name)
									Text(card.number.toSecureCard())
								}
							}
						}
						NavigationLink(destination: CardView(card: PartCardData(card: CardData(id: .init(), number: "", cvv: "", expiration: "", nickname: "", type: .creditCard)), context)) {
							Text("Add a new \(type.rawValue)")
								.foregroundStyle(.blue)
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

	func generateDefaultDate() {
	}
}

#Preview {
	HomeView()
}
