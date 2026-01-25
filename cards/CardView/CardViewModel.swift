//
//  CardViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 28/01/24.
//

import SwiftUI
import LocalAuthentication

#if os(iOS)
import PhotosUI
#endif

class CardViewModel: ObservableObject {

	@Published var card : CardData
	@Published var isEditing = false
	@Published var cardImage: PlatformImage?
	@AppStorage("auth") var isAuthenticated = false
	@Published var isShowingScanner = false
	@Published var errorMessage: String?
	@Published var showErrorAlert = false

	#if os(iOS)
	@Published var selectedItem: PhotosPickerItem?
	#endif

	var isAddNewFlow : Bool
	var addUpdateCard: (CardData) -> Void

	init(card: CardData, isEditing: Bool = false, addNewFlow: Bool = false, addUpdateCard: @escaping ((CardData) -> Void) ) {
		self.card = card
		self.isEditing = isEditing
		self.addUpdateCard = addUpdateCard
		self.isAddNewFlow = addNewFlow
		cardImage = ICloudDataManager.shared.loadImage(for: card.id)
	}

	func authenticateUser() {
		let context = LAContext()
		var error: NSError?

		if !UserSettings.shared.isAuthEnabled {
			Task { @MainActor in
				isAuthenticated = true
			}
			return
		}
		let reason = "Please authenticate to view your card details."

		// Check if the device supports biometric authentication
		if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
			context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
				Task { @MainActor in
					self.isAuthenticated = success
				}
			}
		} else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
			// Fallback to password/passcode authentication when biometrics unavailable
			context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
				Task { @MainActor in
					self.isAuthenticated = success
				}
			}
		} else {
			Task { @MainActor in
				isAuthenticated = false
			}
		}
	}

	func copyAction(with value: String) {
		guard !value.isEmpty else {
			HapticService.trigger(.error)
			return
		}
		PasteboardService.copy(value)
		HapticService.trigger(.success)
	}
}
