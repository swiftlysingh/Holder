//
//  SettingsViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 30/01/24.
//

import Settings
import SwiftUI
import StoreKit

#if os(iOS)
import UIKit
#endif

struct SettingsViewModel: SettingsViewModelProtocol {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var privacyPolicy: String {
        "https://docs.google.com/document/d/1OD3foirDwAsmZ8Mp6cYJlDpUjAyDpvgX7rvzosnNQes"
    }

    var sourceCode: String? {
        "https://github.com/swiftlysingh/holder/"
    }

    @ViewBuilder var appSettings: some View {
        AppSettingsView()
    }

    func rateTheAppAction() {
        ReviewService.requestReview()
    }
}
