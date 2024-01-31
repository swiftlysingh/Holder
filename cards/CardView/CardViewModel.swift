//
//  CardViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 28/01/24.
//

import SwiftUI
import LocalAuthentication

class CardViewModel: ObservableObject {

	@Published var card : CardData
	@Published var isEditing = false
	@Published var isAuthenticated = false
	@Published var isShowingScanner = false

	var isAddNewFlow : Bool
	var addUpdateCard: (CardData) -> Void

	init(card: CardData, isEditing: Bool = false, addNewFlow: Bool = false, addUpdateCard: @escaping ((CardData) -> Void) ) {
		self.card = card
		self.isEditing = isEditing
		self.addUpdateCard = addUpdateCard
		self.isAddNewFlow = addNewFlow
	}

	func authenticateUser() {
		let context = LAContext()
		var error: NSError?

		// Check if the device supports biometric authentication
		if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
			let reason = "Please authenticate to view your card details."
			context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
				DispatchQueue.main.async {
					if success {
						self.isAuthenticated = true
					} else {
						self.isAuthenticated = false
					}
				}
			}
		} else {
			isAuthenticated = false
		}
	}

	func copyAction(with value: String) {
		let generator = UINotificationFeedbackGenerator()
		guard !value.isEmpty else {
			generator.notificationOccurred(.error)
			return
		}
		print("log: Copied With item: \(value)")
		UIPasteboard.general.string = value
		generator.notificationOccurred(.success)
	}
}
