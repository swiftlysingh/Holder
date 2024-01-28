//
//  Extensions.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import SwiftUI

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
