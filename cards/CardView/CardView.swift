//
//  CardView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import SwiftUI

struct CardView: View {
	
	@ObservedObject var model: CardViewModel
	
	var body: some View {
		getCardListView()
			.onAppear {
				model.authenticateUser()
			}
	}

	fileprivate func itemView(heading : String, value : Binding<String>,_ type: UIKeyboardType) -> some View {
		return HStack{
			Text(heading)
				.bold()
			Spacer()
			if model.isAuthenticated || (model.isEditing) {
				TextField("", text: value)
					.multilineTextAlignment(.trailing)
					.disabled(!model.isEditing)
					.foregroundColor(model.isEditing ? .blue : .accentColor)
					.keyboardType(type)
					.contextMenu(menuItems: {
						Button(action: {
							model.copyAction(with: value.wrappedValue)
						}) {
							Text("Copy to clipboard")
							Image(systemName: "doc.on.doc")
						}
					})
				//					https://codingwithrashid.com/how-to-limit-characters-in-ios-swiftui-textfield/
			} else {
				SecureField("", text: value)
					.multilineTextAlignment(.trailing)
			}
		}
		.contentShape(Rectangle())
		.onTapGesture {
			model.copyAction(with: value.wrappedValue)
		}
	}

	fileprivate func getCardListView() -> some View {
		let tip = DoubleTapTip()

		return List {
			itemView(heading: "Name", value: model.$card.name, .alphabet)
			itemView(heading: "Number", value: model.$card.number,.numberPad)
				.if(!model.isEditing) { viewy in
					viewy.popoverTip(tip,arrowEdge: .top)
				}
			itemView(heading: "Expiration", value: model.$card.expiration, .numberPad)
			itemView(heading: "Security Code", value: model.$card.cvv, .numberPad)
			itemView(heading: "Description", value: model.$card.description, .alphabet)
			Picker("Card Type", selection: model.$card.type){
				ForEach(CardType.allCases) { pref in
					Text(pref.rawValue)
				}
			}
			.disabled(!model.isEditing)
			.bold()
		}
		.navigationTitle("Credit Cards")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			Button(model.isEditing ? "Done" : "Edit") {
				if !model.card.number.isEmpty{
					guard let addUpdateCard = model.addUpdateCard else {return}
					(addUpdateCard)(model.card)
				}
				model.isEditing.toggle()
			}
			.disabled(!model.isAuthenticated)
		}
	}
}
