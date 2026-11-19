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
        URL(string: "https://holder.promptside.studio/privacy")
    }

    var sourceCodeURL: URL? {
        URL(string: "https://github.com/swiftlysingh/holder/")
    }

    var showsSubscriptionManagement: Bool { false }

    var linesOfCode: Int? { LinesOfCode.appCount }

    @ViewBuilder var appSettings: some View {
        AppSettingsView()
    }
    
    var appReview: AppReviewConfiguration = .appStoreID("6475649492")
}
