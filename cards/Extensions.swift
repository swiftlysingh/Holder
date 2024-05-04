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
	func getCardNetwork() -> CardNetwork {
		guard let number = UInt(self) else {return .other}
		
		let first2Digits = number.firstDigits(count: 2)
		if number.firstDigits(count: 1) == 4 {
			return .visa
		} else if first2Digits == 34 || first2Digits == 37 {
			return .amex
		} else if first2Digits == 36 || first2Digits == 38 || first2Digits == 30 {
			return .diners
		} else if first2Digits == 60 || first2Digits == 65 || first2Digits == 81 || first2Digits == 82 {
            return .rupay
        } else {
			return .master
		}
	}
}
extension UInt {
	func firstDigits(count: Int) -> UInt {
		if self == 0 || count <= 0 {
			return 0
		}
		let digits = Int(log10(Double(self)))
		if digits + 1 <= count {  // If the number of requested digits is more than or equal to the number's total digits
			return self
		}
		let divisor = UInt(pow(10.0, Double(digits - count + 1)))
		return self / divisor
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
