//
//  SettingsViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 30/01/24.
//

import SinghDevKit
import SwiftUI

#if os(iOS)
import UIKit
#endif

struct SettingsViewModel: SettingsViewModelProtocol {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var privacyPolicyURL: URL? {
        URL(string: "https://docs.google.com/document/d/1OD3foirDwAsmZ8Mp6cYJlDpUjAyDpvgX7rvzosnNQes")
    }

    var sourceCodeURL: URL? {
        URL(string: "https://github.com/swiftlysingh/holder/")
    }

    var showsSubscriptionManagement: Bool { false }

    @ViewBuilder var appSettings: some View {
        AppSettingsView()
    }
    
    var appReview: AppReviewConfiguration = .appStoreID("6475649492")
}
