//
//  CardView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import SwiftUI
import SwiftData

struct CardView: View {

	@State var card : PartCardData

	@State var isEditing = false



	fileprivate func itemView(heading : String, value : Binding<String>) -> some View {
		return HStack{
			Text(heading)
				.bold()
			Spacer()
			TextField("", text: value)
				.multilineTextAlignment(.trailing)
				.disabled(!isEditing)
				.foregroundColor(isEditing ? .blue : .accentColor)

		}
	}

//	init(card: PartCardData?,_ context: ModelContext, addNew: Bool = false) {
//		if let safeCard = card {
//			self.card = safeCard
//		} else if addNew {
//			let item = PartCardData(card: CardData(id: UUID(), number: "2030 2020 3023 2323", cvv: "3232", expiration:"11/11", nickname: "Visa", type: .creditCard))
//			self.card = item
//			self.isEditing = true
//			context.insert(item)
//		}
//	}

	var body: some View {
		List {
			itemView(heading: "Number", value: $card.number)
//			itemView(heading: "Expiration", value: $card.expiration)
//			itemView(heading: "Security Code", value: $card.cvv)
//			itemView(heading: "Name", value: $card.nickname)
			Picker("Card Type", selection: $card.type){
				ForEach(CardType.allCases) { pref in
					Text(pref.rawValue)
				}
			}
			.bold()
			.disabled(!isEditing)
		}
		.navigationTitle("Credit Cards")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			Button(isEditing ? "Done" : "Edit") {
				isEditing.toggle()
			}
		}
    }
}
