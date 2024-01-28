//
//  UserSettings.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import SwiftUI

class UserSettings : Observable{

	static let shared = UserSettings()
	private init (){}
	
	@AppStorage("username") var showNumber = 4.0

	let appVersion : String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
}