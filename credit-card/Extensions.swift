//
//  Extensions.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import Foundation

extension String {
	func toSecureCard () -> String {
		let spaceCount = self.components(separatedBy: " ").count - 1
		return self.replacing(try! Regex("[0-9]"), maxReplacements: self.count - (spaceCount + Int(UserSettings.shared.$showNumber.wrappedValue))) { val in
			"X"
		}
	}
}
