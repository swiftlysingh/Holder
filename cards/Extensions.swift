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
		guard let number = UInt(self.replacingOccurrences(of: " ", with: "")) else {return .other}
		
		let first2Digits = number.firstDigits(count: 2)
		let first4Digits = number.firstDigits(count: 4)
		
		// Visa: Starts with 4
		if number.firstDigits(count: 1) == 4 {
			return .visa
		}
		// American Express: Starts with 34 or 37
		else if first2Digits == 34 || first2Digits == 37 {
			return .amex
		}
		// Diners Club: Starts with 30, 36, 38, or 39
		else if first2Digits == 36 || first2Digits == 38 || first2Digits == 30 || first2Digits == 39 {
			return .diners
		}
		// RuPay: Starts with 60, 65, 81, 82, or ranges 508500-508999
		else if first2Digits == 60 || first2Digits == 65 || first2Digits == 81 || first2Digits == 82 ||
			(first4Digits >= 5085 && first4Digits <= 5089) {
			return .rupay
		}
		// Mastercard: Starts with 51-55, or 2221-2720
		else if (first2Digits >= 51 && first2Digits <= 55) ||
			(first4Digits >= 2221 && first4Digits <= 2720) {
			return .master
		}
		else {
			return .other
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
