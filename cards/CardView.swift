//
//  CardView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import SwiftUI
import LocalAuthentication
import TipKit


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
            if isAuthenticated || (isEditing) {
				TextField("", text: value)
					.multilineTextAlignment(.trailing)
					.disabled(!isEditing)
					.foregroundColor(isEditing ? .blue : .accentColor)
					.keyboardType(type)
                   .contextMenu(menuItems: {
                                Button(action: {
                                    copyAction(with: value.wrappedValue)
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
            copyAction(with: value.wrappedValue)
        }
	}
    
    private func copyAction(with value: String) {
        let generator = UINotificationFeedbackGenerator()
        guard !value.isEmpty else {
            generator.notificationOccurred(.error)
                return
            }
        print("log: Copied With item: \(value)")
        UIPasteboard.general.string = value
        generator.notificationOccurred(.success)
    }
	
	fileprivate func getCardListView() -> some View {
        let tip = DoubleTapTip()
        
		return List {
            itemView(heading: "Name", value: $card.name, .alphabet)
			itemView(heading: "Number", value: $card.number,.numberPad)
                .if(!isEditing) { viewy in
                    viewy.popoverTip(tip,arrowEdge: .top)
                }
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

struct DoubleTapTip: Tip {
    var title: Text {
        Text("Tap to Copy")
    }
 
    var message: Text? {
        Text("You can tap to copy details")
    }
}

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
