//
//  Extensions.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import SwiftUI

extension String {
	func toSecureCard() -> String {
		guard let components = self.components(separatedBy: " ").last else {return self}

		let baseString = String(repeating: "•", count: 4) + " "
		if components.count > 4 {
			let lastFour = components.suffix(Int(UserSettings.shared.showNumber)) 
			return  baseString + lastFour
		} else {
			return baseString + (components)
		}
	}
}

extension View {
	/// Applies the given transform if the given condition evaluates to `true`.
	/// - Parameters:
	///   - condition: The condition to evaluate.
	///   - transform: The transform to apply to the source `View`.
	/// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
	@ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
		if condition {
			transform(self)
		} else {
			self
		}
	}
}
