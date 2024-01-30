//
//  SettingsViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 30/01/24.
//

import Foundation
import StoreKit


class SettingsViewModel {

	let appVersion : String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

	func requestReview() {
		guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
		SKStoreReviewController.requestReview(in: windowScene)
	}

}
