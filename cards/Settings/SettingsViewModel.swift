//
//  SettingsViewModel.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 30/01/24.
//

import Foundation

class SettingsViewModel {

	let appVersion : String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

}
