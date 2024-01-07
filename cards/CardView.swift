//
//  CardView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import SwiftUI
import LocalAuthentication


struct CardView: View {

	@State var card : CardData
	@State var isEditing = false
	@State private var isAuthenticated = false

	var addUpdateCard: (CardData) -> Void

	fileprivate func itemView(heading : String, value : Binding<String>,_ type: UIKeyboardType) -> some View {
		return HStack{
			Text(heading)
				.bold()
			Spacer()
			if isAuthenticated {
				TextField("", text: value)
					.multilineTextAlignment(.trailing)
					.disabled(!isEditing)
					.foregroundColor(isEditing ? .blue : .accentColor)
					.keyboardType(type)
//					https://codingwithrashid.com/how-to-limit-characters-in-ios-swiftui-textfield/

			} else {
				SecureField("", text: value)
					.multilineTextAlignment(.trailing)
			}
		}
	}
	
	fileprivate func getCardListView() -> some View {
		return List {
			itemView(heading: "Number", value: $card.number,.numberPad)
			itemView(heading: "Expiration", value: $card.expiration, .numberPad)
			itemView(heading: "Security Code", value: $card.cvv, .numberPad)
			itemView(heading: "Name", value: $card.nickname, .alphabet)
			Picker("Card Type", selection: $card.type){
				ForEach(CardType.allCases) { pref in
					Text(pref.rawValue)
				}
			}
			.bold()
		}
		.navigationTitle("Credit Cards")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			Button(isEditing ? "Done" : "Edit") {
				addUpdateCard(card)
				isEditing.toggle()
			}
		}
	}
	
	var body: some View {
		getCardListView()
			.onAppear {
				authenticateUser()
			}
	}

	private func authenticateUser() {
		let context = LAContext()
		var error: NSError?

		// Check if the device supports biometric authentication
		if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
			let reason = "Please authenticate to view your card details."
			context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
				DispatchQueue.main.async {
					if success {
						isAuthenticated = true
					} else {
						isAuthenticated = false
					}
				}
			}
		} else {
			isAuthenticated = false
		}
	}

}
