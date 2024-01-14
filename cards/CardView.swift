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
//    @State private var didTap = false

	var addUpdateCard: (CardData) -> Void

	fileprivate func itemView(heading : String, value : Binding<String>,_ type: UIKeyboardType) -> some View {
		return HStack{
			Text(heading)
				.bold()
			Spacer()
            if isAuthenticated || (isEditing) {
				TextField("", text: value)
					.multilineTextAlignment(.trailing)
					.disabled(!isEditing)
					.foregroundColor(isEditing ? .blue : .accentColor)
					.keyboardType(type)
                   .contextMenu(menuItems: {
                                Button(action: {
                                    UIPasteboard.general.string = value.wrappedValue
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
        .onTapGesture(count: 2) {
            UIPasteboard.general.string = value.wrappedValue
        }
// Popover not showing.
//        .onTapGesture {
//            print("Lalala")
//            didTap = true
//            print(didTap)
//        }
//        .popover(isPresented: $didTap) {
//            Button("Copy") {
//                UIPasteboard.general.string = value.wrappedValue
//                print("Copied: \(value.wrappedValue)")
//                didTap = false
//            }
//        }
	}
	
	fileprivate func getCardListView() -> some View {
		return List {
            itemView(heading: "Name", value: $card.name, .alphabet)
			itemView(heading: "Number", value: $card.number,.numberPad)
			itemView(heading: "Expiration", value: $card.expiration, .numberPad)
			itemView(heading: "Security Code", value: $card.cvv, .numberPad)
            itemView(heading: "Description", value: $card.description, .alphabet)
			Picker("Card Type", selection: $card.type){
				ForEach(CardType.allCases) { pref in
					Text(pref.rawValue)
				}
			}
            .disabled(!isEditing)
			.bold()
		}
		.navigationTitle("Credit Cards")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			Button(isEditing ? "Done" : "Edit") {
                if !card.number.isEmpty{
                        addUpdateCard(card)
                }
				isEditing.toggle()
			}
            .disabled(!isAuthenticated)
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
