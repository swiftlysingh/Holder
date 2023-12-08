//
//  CardView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import SwiftUI

struct CardView: View {

	@State var card : Card

	@State var edit = true

	fileprivate func itemView(heading : String, value : Binding<String>) -> some View {
		return HStack{
			Text(heading)
				.bold()
			Spacer()
			TextField("", text: value)
				.multilineTextAlignment(.trailing)
				.disabled(edit)
				.foregroundColor(edit ? .accentColor : .blue)

		}
	}
	
	var body: some View {
		List {
			itemView(heading: "Number", value: $card.number)
			itemView(heading: "Expiration", value: $card.expiration)
			itemView(heading: "Security Code", value: $card.cvv)
			itemView(heading: "Name", value: $card.nickname)
		}
		.navigationTitle("Credit Cards")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			Button("Edit") {
				edit.toggle()
			}
		}
    }
}
