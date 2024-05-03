//
//  SettingsViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 30/01/24.
//

import Settings
import UIKit
import SwiftUI
import StoreKit

class SettingsViewModel: SettingsViewModelProtocol {
    var appVersion : String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    
    var privacyPolicy = "https://docs.google.com/document/d/1OD3foirDwAsmZ8Mp6cYJlDpUjAyDpvgX7rvzosnNQes"

    var sourceCode: String? = "https://github.com/swiftlysingh/holder/"
    
    var appSettings: AnyView? = AppSettingsView().body
    
    func rateTheAppAction() {
        guard let windowScene =  UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: windowScene)
    }
}
