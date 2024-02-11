//
//  CardView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import SwiftUI

struct CardView: View {
	
	@ObservedObject var model: CardViewModel
	@Environment(\.scenePhase) var scenePhase

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
			if !model.isAuthenticated {
				SecureField("", text: value)
					.multilineTextAlignment(.trailing)
			} else {
				TextField("", text: value)
					.multilineTextAlignment(.trailing)
					.disabled(!model.isEditing)
					.foregroundColor(model.isEditing ? .blue : .primary)
					.keyboardType(type)
					.contextMenu(menuItems: {
						Button(action: {
							model.copyAction(with: value.wrappedValue)
						}) {
							Text("Copy to clipboard")
							Image(systemName: "doc.on.doc")
						}
					})
			}
		}
		.if (!model.isEditing, transform: { view in
			view.onTapGesture {
					model.copyAction(with: value.wrappedValue)
				}
		})
	}

	fileprivate func getCardListView() -> some View {
		let tip = DoubleTapTip()

		return List {
			itemView(heading: "Name", value: $model.card.name, .alphabet)
			itemView(heading: "Number", value: $model.card.number,.numberPad)
				.if(!model.isEditing) { viewy in
					viewy.popoverTip(tip,arrowEdge: .top)
				}
			itemView(heading: "Expiration", value: $model.card.expiration, .numberPad)
			itemView(heading: "Security Code", value: $model.card.cvv, .numberPad)
			itemView(heading: "Description", value: $model.card.description, .alphabet)
			Picker("Card Type", selection: $model.card.type){
				ForEach(CardType.allCases) { pref in
					Text(pref.rawValue)
				}
			}
			.disabled(!model.isEditing)
			.bold()
		}
		.toolbar {
			Button(action: {
				model.isEditing.toggle()
				// if user is not editing, then he is done editing when button press
				if !$model.isEditing.wrappedValue && !model.card.number.isEmpty {
					model.addUpdateCard(model.card)
				}
			}) {
				Text(model.isEditing ? "Done" : "Edit")
			}
			.disabled(!$model.isAuthenticated.wrappedValue)
		}
		.toolbar {
			if model.card.number.isEmpty {
				ToolbarItem(placement: .topBarLeading){
					Button(action: {
						model.isShowingScanner = true
					}, label: {
						Image(systemName: "camera.on.rectangle")
					})
					.if(!model.isAddNewFlow, transform: { view in
						view.hidden()
					})

					// .screen was causing issues with camera session not closing
					#if os(iOS)
					.fullScreenCover(isPresented: $model.isShowingScanner) {
						SharkCardScanViewRepresentable(
							noPermissionAction: {
								//TODO: Handle no permission case
								print("Error No Permission")
							},
							successHandler: { response in
								DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
									model.card.number = response.number
									model.card.name = response.holder ?? ""
									model.card.expiration = response.expiry ?? ""
									model.isShowingScanner = false
									print(response.number,response.holder as Any,response.expiry as Any)
								}
							}
						)
					}
					#endif
				}
			}
		}
		.onChange(of: scenePhase) {
			if scenePhase == .background {
				DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(UserSettings.shared.authTimeout)) {
					if scenePhase == .background {
						self.model.$isAuthenticated.wrappedValue = false
					}
				}
			}
		}
		.onDisappear(perform: {
			model.$isAuthenticated.wrappedValue = false
		})
	}
}
