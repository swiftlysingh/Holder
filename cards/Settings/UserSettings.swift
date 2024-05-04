//
//  UserSettings.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import SwiftUI
import StoreKit

class UserSettings : ObservableObject {
	static let shared = UserSettings()
	private init (){}
	
	@AppStorage("username") var showNumber = 4.0
	@AppStorage("timeout") var authTimeout = 10
	@AppStorage("isAuthEnabled") var isAuthEnabled = true
    
    func requestReview() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: windowScene)
    }
}
