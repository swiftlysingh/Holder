//
//  Extensions.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import Foundation

extension String {
	func toSecureCard() -> String {
		let components = self.components(separatedBy: " ")
		let processedComponents = components.map { component -> String in
			if component.count > 4 {
				let lastFour = component.suffix(4)
				return String(repeating: "•", count: component.count - 4) + " " + lastFour
			} else {
				return component
			}
		}
		return processedComponents.joined(separator: " ")
	}
}
