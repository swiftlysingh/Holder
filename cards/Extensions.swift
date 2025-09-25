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
		
		let first1 = number.firstDigits(count: 1)
		let first2Digits = number.firstDigits(count: 2)
		let first3Digits = number.firstDigits(count: 3)
		let first4Digits = number.firstDigits(count: 4)
		let first6Digits = number.firstDigits(count: 6)
		
		// Visa: Starts with 4
		if first1 == 4 {
			return .visa
		}
		// American Express: Starts with 34 or 37
		else if first2Digits == 34 || first2Digits == 37 {
			return .amex
		}
		// Mastercard: 51–55 or 2221–2720
		else if (first2Digits >= 51 && first2Digits <= 55) ||
			(first4Digits >= 2221 && first4Digits <= 2720) {
			return .master
		}
		// Discover: 6011, 65, 644–649, 622126–622925
		else if first4Digits == 6011 || first2Digits == 65 ||
			(first3Digits >= 644 && first3Digits <= 649) ||
			(first6Digits >= 622126 && first6Digits <= 622925) {
			return .discover
		}
		// JCB: 3528–3589
		else if first4Digits >= 3528 && first4Digits <= 3589 {
			return .jcb
		}
		// Diners Club: 300–305, 309, 36, 38–39
		else if (first3Digits >= 300 && first3Digits <= 305) || first3Digits == 309 ||
			first2Digits == 36 || (first2Digits >= 38 && first2Digits <= 39) {
			return .diners
		}
		// UnionPay: Starts with 62 (avoid clash with Discover 622126–622925 handled above)
		else if first2Digits == 62 {
			return .unionPay
		}
		// RuPay: 60 (not 6011), 5085–5089, 81, 82
		else if (first2Digits == 60 && first4Digits != 6011) ||
			(first4Digits >= 5085 && first4Digits <= 5089) ||
			first2Digits == 81 || first2Digits == 82 {
			return .rupay
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
