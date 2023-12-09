//
//  ContentView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI

struct HomeView: View {

	var cards : [Card] = [ Card(id: UUID(), number: "2030 202030 2020", cvv: "3232", expiration: "11/11", nickname: "American Express"),
						   Card(id: UUID(), number: "2030 2020 3023 2323", cvv: "3232", expiration:"11/11", nickname: "Visa"),
						   Card(id: UUID(), number: "2030 2020 3032 2020", cvv: "3232", expiration: "11/11", nickname: "Visa")
	]

	var body: some View {
		NavigationStack {
			List{
				Section{
					ForEach(cards) { card in
						NavigationLink(destination: CardView(card: card )){
							VStack(alignment: .leading){
								Text(card.nickname)
								Text(card.number.toSecureCard())

							}
						}
					}
					NavigationLink(destination: CardView(card: .init(id: UUID(), number: "", cvv: "", expiration: "", nickname: ""), isEditing: true)) {
						Text("Add new card")
							.foregroundStyle(.blue)
					}

				}
			header: {
				Text("Credit Cards")
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

struct Card: Identifiable {
	var id : UUID
	var number : String
	var cvv : String
	var expiration : String
	var nickname : String
}

#Preview {
    HomeView()
}
