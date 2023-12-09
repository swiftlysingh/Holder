//
//  ContentView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI

struct HomeView: View {

	var cards : [CardData] = [ CardData(id: UUID(), number: "2030 202030 2020", cvv: "3232", expiration: "11/11", nickname: "American Express", type: .creditCard),
							   CardData(id: UUID(), number: "2030 2020 3023 2323", cvv: "3232", expiration:"11/11", nickname: "Visa", type: .debitCard),
							   CardData(id: UUID(), number: "2030 2020 3032 2020", cvv: "3232", expiration: "11/11", nickname: "Visa", type: .creditCard)
	]

	var body: some View {
		NavigationStack {
			List{
				Section(header: Text("\(CardType.creditCard.rawValue)s")){
					ForEach(cards.filter({ cardData in
						cardData.type == CardType.creditCard
					})) { card in
						NavigationLink(destination: CardView(card: card )){
							VStack(alignment: .leading){
								Text(card.nickname)
								Text(card.number.toSecureCard())
							}
						}
					}
					NavigationLink(destination: CardView(card: .init(id: UUID(), number: "", cvv: "", expiration: "", nickname: "", type: .creditCard), isEditing: true)) {
						Text("Add a new \(CardType.creditCard.rawValue)")
							.foregroundStyle(.blue)
					}
				}
				Section(header: Text("\(CardType.debitCard.rawValue)s")){
					ForEach(cards.filter({ cardData in
						cardData.type == CardType.debitCard
					})) { card in
						NavigationLink(destination: CardView(card: card )){
							VStack(alignment: .leading){
								Text(card.nickname)
								Text(card.number.toSecureCard())
							}
						}
					}
					NavigationLink(destination: CardView(card: .init(id: UUID(), number: "", cvv: "", expiration: "", nickname: "", type: .creditCard), isEditing: true)) {
						Text("Add a new \(CardType.debitCard.rawValue)")
							.foregroundStyle(.blue)
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
