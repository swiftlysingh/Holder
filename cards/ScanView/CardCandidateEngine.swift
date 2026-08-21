//
//  CardCandidateEngine.swift
//  cards
//
//  Reconstructs PANs from split/multi-line OCR, votes across frames, and
//  parses expiry / cardholder name. PAN acceptance requires 13–19 digits,
//  Luhn, and a known network/IIN.
//

import CoreGraphics
import Foundation

struct OCRTextItem: Equatable, Sendable {
	var text: String
	var candidates: [String]
	var boundingBox: CGRect?

	init(text: String, candidates: [String] = [], boundingBox: CGRect? = nil) {
		self.text = text
		self.candidates = candidates.isEmpty ? [text] : candidates
		self.boundingBox = boundingBox
	}
}

enum CardPAN {
	static let minimumLength = 13
	static let maximumLength = 19

	/// Safe numeric OCR substitutions, applied only to tokens that already look numeric.
	private static let substitutions: [Character: Character] = [
		"O": "0", "o": "0", "Q": "0",
		"I": "1", "l": "1", "|": "1",
		"Z": "2", "z": "2",
		"S": "5", "s": "5",
		"G": "6",
		"B": "8"
	]

	static func digits(in raw: String, allowOCRNormalization: Bool = true) -> String {
		let normalized = allowOCRNormalization ? normalizeNumericToken(raw) : raw
		return normalized.filter(\.isNumber)
	}

	static func normalizeNumericToken(_ raw: String) -> String {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmed.contains(where: \.isNumber) else { return raw }

		let nonSeparator = trimmed.filter { !$0.isWhitespace && $0 != "-" && $0 != "/" }
		let digitLikeCount = nonSeparator.filter { $0.isNumber || substitutions[$0] != nil }.count
		guard !nonSeparator.isEmpty, Double(digitLikeCount) / Double(nonSeparator.count) >= 0.6 else {
			return raw
		}

		return String(trimmed.map { substitutions[$0] ?? $0 })
	}

	static func isLuhnValid(_ digits: String) -> Bool {
		guard (minimumLength...maximumLength).contains(digits.count),
			  digits.allSatisfy(\.isNumber) else {
			return false
		}

		var sum = 0
		for (index, character) in digits.reversed().enumerated() {
			guard let digit = character.wholeNumberValue else { return false }
			if index % 2 == 1 {
				let doubled = digit * 2
				sum += doubled > 9 ? doubled - 9 : doubled
			} else {
				sum += digit
			}
		}
		return sum % 10 == 0
	}

	static func formatted(_ digits: String) -> String {
		if digits.count == 15 {
			let first = digits.prefix(4)
			let middle = digits.dropFirst(4).prefix(6)
			let last = digits.dropFirst(10)
			return [first, middle, last].map(String.init).joined(separator: " ")
		}

		let chunks = stride(from: 0, to: digits.count, by: 4).map { offset -> String in
			let start = digits.index(digits.startIndex, offsetBy: offset)
			let end = digits.index(start, offsetBy: min(4, digits.count - offset))
			return String(digits[start..<end])
		}
		return chunks.joined(separator: " ")
	}

	/// String IIN matching so 19-digit PANs are not truncated by `UInt`.
	static func network(for digits: String) -> CardNetwork {
		guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return .other }

		func prefix(_ count: Int) -> Int? {
			guard digits.count >= count else { return nil }
			return Int(digits.prefix(count))
		}

		let first1 = prefix(1)
		let first2 = prefix(2)
		let first3 = prefix(3)
		let first4 = prefix(4)
		let first6 = prefix(6)

		if first1 == 4 { return .visa }
		if first2 == 34 || first2 == 37 { return .amex }
		if let first2, (51...55).contains(first2) { return .master }
		if let first4, (2221...2720).contains(first4) { return .master }
		if first4 == 6011 || first2 == 65 { return .discover }
		if let first3, (644...649).contains(first3) { return .discover }
		if let first6, (622126...622925).contains(first6) { return .discover }
		if let first4, (3528...3589).contains(first4) { return .jcb }
		if let first3, (300...305).contains(first3) || first3 == 309 { return .diners }
		if first2 == 36 || (first2 ?? 0) >= 38 && (first2 ?? 0) <= 39 { return .diners }
		if first2 == 62 { return .unionPay }
		if first2 == 81 || first2 == 82 { return .rupay }
		if let first4, (5085...5089).contains(first4) { return .rupay }
		if first2 == 60, first4 != 6011 { return .rupay }
		return .other
	}

	static func validatedPAN(from raw: String, allowOCRNormalization: Bool = true) -> String? {
		let digits = digits(in: raw, allowOCRNormalization: allowOCRNormalization)
		return validatedDigits(digits)
	}

	static func validatedDigits(_ digits: String) -> String? {
		guard isLuhnValid(digits) else { return nil }
		guard network(for: digits) != .other else { return nil }
		return digits
	}
}

enum CardExpiryParser {
	static func parse(_ raw: String, now: Date = Date()) -> String? {
		let compact = raw.uppercased()
			.replacingOccurrences(of: "-", with: "/")
			.replacingOccurrences(of: ".", with: "/")

		let patterns = [
			#"\b(0[1-9]|1[0-2])\s*/\s*((?:20)?[0-9]{2})\b"#,
			#"\b(0[1-9]|1[0-2])((?:20)?[0-9]{2})\b"#
		]

		for pattern in patterns {
			if let match = firstMatch(pattern, in: compact) {
				if let formatted = validated(month: match.0, year: match.1, now: now) {
					return formatted
				}
			}
		}
		return nil
	}

	static func validated(month: String, year rawYear: String, now: Date) -> String? {
		guard let monthValue = Int(month), (1...12).contains(monthValue) else { return nil }

		let yearDigits: String
		if rawYear.count == 4, rawYear.hasPrefix("20") {
			yearDigits = String(rawYear.suffix(2))
		} else if rawYear.count == 2 {
			yearDigits = rawYear
		} else {
			return nil
		}

		guard let yearValue = Int(yearDigits) else { return nil }
		let calendar = Calendar(identifier: .gregorian)
		let presentYear = calendar.component(.year, from: now) % 100
		let maxYear = presentYear + 10
		guard yearValue >= presentYear, yearValue <= maxYear else { return nil }

		if yearValue == presentYear {
			let presentMonth = calendar.component(.month, from: now)
			if monthValue < presentMonth { return nil }
		}

		return String(format: "%02d/%@", monthValue, yearDigits)
	}

	private static func firstMatch(_ pattern: String, in text: String) -> (String, String)? {
		guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
		let range = NSRange(text.startIndex..., in: text)
		guard let match = regex.firstMatch(in: text, range: range),
			  match.numberOfRanges >= 3,
			  let monthRange = Range(match.range(at: 1), in: text),
			  let yearRange = Range(match.range(at: 2), in: text) else {
			return nil
		}
		return (String(text[monthRange]), String(text[yearRange]))
	}
}

enum CardholderNameParser {
	private static let blocked: Set<String> = [
		"VISA", "MASTERCARD", "MASTER CARD", "AMEX", "AMERICAN EXPRESS",
		"DISCOVER", "RUPAY", "UNIONPAY", "UNION PAY", "JCB", "DINERS",
		"DINERS CLUB", "VALID", "THRU", "GOOD", "FROM", "MONTH", "YEAR",
		"DEBIT", "CREDIT", "BANK", "CARD", "PLATINUM", "SIGNATURE",
		"WORLD", "ELECTRON", "CLASSIC", "GOLD", "TITANIUM", "BUSINESS",
		"VALID THRU", "GOOD THRU", "MEMBER SINCE", "CVV", "CVC", "CID"
	]

	static func parse(from items: [OCRTextItem], panDigits: String?) -> String? {
		let panDigits = panDigits ?? ""
		let candidates = items.compactMap { item -> (name: String, box: CGRect?)? in
			guard let name = normalizedName(item.text, panDigits: panDigits) else { return nil }
			return (name, item.boundingBox)
		}
		guard !candidates.isEmpty else { return nil }

		if candidates.allSatisfy({ $0.box != nil }) {
			return candidates
				.sorted { ($0.box?.minY ?? 0) > ($1.box?.minY ?? 0) }
				.first?
				.name
		}
		return candidates.last?.name
	}

	static func normalizedName(_ raw: String, panDigits: String = "") -> String? {
		let compactDigits = CardPAN.digits(in: raw, allowOCRNormalization: false)
		if compactDigits.count >= 8 { return nil }
		if CardExpiryParser.parse(raw) != nil { return nil }

		let letters = raw
			.replacingOccurrences(of: ",", with: " ")
			.split(whereSeparator: { $0.isWhitespace || $0 == "." })
			.map { $0.trimmingCharacters(in: .punctuationCharacters) }
			.filter { !$0.isEmpty }

		guard letters.count >= 2, letters.count <= 4 else { return nil }

		let joined = letters.joined(separator: " ").uppercased()
		if blocked.contains(joined) { return nil }

		var cleaned: [String] = []
		for token in letters {
			let upper = token.uppercased()
			if blocked.contains(upper) { continue }
			guard token.count >= 2, token.count <= 20 else { return nil }
			let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: "'-"))
			guard token.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
				return nil
			}
			cleaned.append(upper)
		}

		guard cleaned.count >= 2 else { return nil }
		if !panDigits.isEmpty, CardPAN.digits(in: joined).count >= 8 { return nil }
		return cleaned.joined(separator: " ")
	}
}

struct CardFrameObservation: Equatable {
	var pan: String?
	var expiry: String?
	var cardholderName: String?
}

enum CardCandidateEngine {
	static func observe(_ items: [OCRTextItem], now: Date = Date()) -> CardFrameObservation {
		let pans = reconstructPANs(from: items)
		let pan = pans.first
		return CardFrameObservation(
			pan: pan,
			expiry: parseExpiry(from: items, now: now),
			cardholderName: CardholderNameParser.parse(from: items, panDigits: pan)
		)
	}

	static func reconstructPANs(from items: [OCRTextItem]) -> [String] {
		var found: [String] = []
		var seen = Set<String>()

		func append(_ pan: String?) {
			guard let pan, seen.insert(pan).inserted else { return }
			found.append(pan)
		}

		for item in items {
			for candidate in item.candidates {
				append(CardPAN.validatedPAN(from: candidate))
			}
		}

		let ordered = orderedItems(items)
		let digitGroups = ordered.flatMap { item in
			item.candidates.flatMap { tokenizeDigitGroups(in: $0) }
		}

		for pan in pans(fromConsecutiveGroups: digitGroups) {
			append(pan)
		}

		let verticalGroups = orderedItems(items, vertical: true).flatMap { tokenizeDigitGroups(in: $0.text) }
		for pan in pans(fromConsecutiveGroups: verticalGroups) {
			append(pan)
		}

		let concatenated = digitGroups.joined()
		append(longestValidPAN(in: concatenated))
		append(longestValidPAN(in: ordered.map(\.text).joined()))

		return found
	}

	static func parseExpiry(from items: [OCRTextItem], now: Date = Date()) -> String? {
		for item in items {
			for candidate in item.candidates {
				if let expiry = CardExpiryParser.parse(candidate, now: now) {
					return expiry
				}
			}
		}
		return nil
	}

	private static func tokenizeDigitGroups(in text: String) -> [String] {
		let normalized = CardPAN.normalizeNumericToken(text)
		let groups = normalized.split { !$0.isNumber }.map(String.init)
		return groups.filter { (4...8).contains($0.count) || (13...19).contains($0.count) }
	}

	private static func pans(fromConsecutiveGroups groups: [String]) -> [String] {
		guard groups.count >= 2 else {
			return groups.compactMap(CardPAN.validatedDigits)
		}

		var pans: [String] = []
		for start in 0..<groups.count {
			var combined = ""
			for end in start..<groups.count {
				combined += groups[end]
				if combined.count > CardPAN.maximumLength { break }
				if let pan = CardPAN.validatedDigits(combined) {
					pans.append(pan)
				}
			}
		}
		return pans
	}

	private static func longestValidPAN(in digitsAndText: String) -> String? {
		let digits = CardPAN.digits(in: digitsAndText)
		guard digits.count >= CardPAN.minimumLength else { return nil }

		var best: String?
		for length in stride(from: min(CardPAN.maximumLength, digits.count), through: CardPAN.minimumLength, by: -1) {
			guard digits.count >= length else { continue }
			let maxStart = digits.count - length
			for start in 0...maxStart {
				let index = digits.index(digits.startIndex, offsetBy: start)
				let end = digits.index(index, offsetBy: length)
				if let pan = CardPAN.validatedDigits(String(digits[index..<end])) {
					best = pan
					break
				}
			}
			if best != nil { break }
		}
		return best
	}

	private static func orderedItems(_ items: [OCRTextItem], vertical: Bool = false) -> [OCRTextItem] {
		guard items.contains(where: { $0.boundingBox != nil }) else { return items }

		return items.sorted { lhs, rhs in
			let left = lhs.boundingBox ?? .zero
			let right = rhs.boundingBox ?? .zero
			if vertical {
				if abs(left.minX - right.minX) > 0.08 {
					return left.minX < right.minX
				}
				return left.maxY > right.maxY
			}
			if abs(left.maxY - right.maxY) > 0.04 {
				return left.maxY > right.maxY
			}
			return left.minX < right.minX
		}
	}
}

/// Rolling-window vote so a single high-confidence OCR miss does not become the PAN.
struct TemporalPANVoter: Sendable {
	var windowSize: Int
	var requiredVotes: Int
	private var recent: [String] = []

	init(windowSize: Int = 8, requiredVotes: Int = 2) {
		self.windowSize = windowSize
		self.requiredVotes = requiredVotes
	}

	mutating func reset() {
		recent.removeAll()
	}

	mutating func record(_ pan: String) -> String? {
		recent.append(pan)
		if recent.count > windowSize {
			recent.removeFirst(recent.count - windowSize)
		}

		var counts: [String: Int] = [:]
		for value in recent {
			counts[value, default: 0] += 1
		}

		guard let winner = counts.max(by: { lhs, rhs in
			if lhs.value == rhs.value {
				return lhs.key < rhs.key
			}
			return lhs.value < rhs.value
		}), winner.value >= requiredVotes else {
			return nil
		}

		let competing = counts.filter { $0.key != winner.key && $0.value == winner.value }
		if !competing.isEmpty {
			return nil
		}
		return winner.key
	}
}
