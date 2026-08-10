//
//  HolderTheme.swift
//  Holder
//
//  The small, shared token set for the Emerald Mint redesign. These values are
//  deliberately expressed as semantic roles so the UI remains readable in
//  either system appearance and does not rely on color alone for meaning.
//

import SwiftUI

enum HolderTheme {
	static let surface = Color(red: 0.953, green: 0.980, blue: 0.965)
	static let elevatedSurface = Color(red: 1, green: 1, blue: 1)
	static let ink = Color(red: 0.063, green: 0.231, blue: 0.196)
	static let secondaryInk = Color(red: 0.247, green: 0.420, blue: 0.365)
	static let brand = Color(red: 0.071, green: 0.286, blue: 0.243)
	static let brandRaised = Color(red: 0.090, green: 0.365, blue: 0.307)
	static let mint = Color(red: 0.716, green: 0.953, blue: 0.812)
	static let mintInk = Color(red: 0.035, green: 0.196, blue: 0.153)
	static let softMint = Color(red: 0.878, green: 0.953, blue: 0.910)
	static let line = Color(red: 0.818, green: 0.900, blue: 0.851)
	static let warning = Color(red: 0.671, green: 0.290, blue: 0.087)

	static let cardPalette: [Color] = [
		Color(red: 0.435, green: 0.235, blue: 0.337),
		Color(red: 0.419, green: 0.333, blue: 0.105),
		Color(red: 0.132, green: 0.389, blue: 0.227),
		Color(red: 0.333, green: 0.204, blue: 0.473),
		Color(red: 0.114, green: 0.310, blue: 0.500)
	]

	static let deckCornerRadius: CGFloat = 18
	static let sheetCornerRadius: CGFloat = 26

	static func background(for colorScheme: ColorScheme) -> Color {
		colorScheme == .dark
			? Color(red: 0.071, green: 0.110, blue: 0.098)
			: surface
	}

	static func raisedSurface(for colorScheme: ColorScheme) -> Color {
		colorScheme == .dark
			? Color(red: 0.102, green: 0.153, blue: 0.135)
			: elevatedSurface
	}

	static func primaryText(for colorScheme: ColorScheme) -> Color {
		colorScheme == .dark ? Color(red: 0.930, green: 0.974, blue: 0.946) : ink
	}

	static func secondaryText(for colorScheme: ColorScheme) -> Color {
		colorScheme == .dark ? Color(red: 0.654, green: 0.789, blue: 0.722) : secondaryInk
	}

	static func separator(for colorScheme: ColorScheme) -> Color {
		colorScheme == .dark ? Color.white.opacity(0.14) : line
	}

	static func paletteColor(for identifier: UUID) -> Color {
		let value = identifier.uuidString.unicodeScalars.reduce(0) { partialResult, scalar in
			partialResult &+ Int(scalar.value)
		}
		let index = value % cardPalette.count
		return cardPalette[index]
	}

	/// A saved palette always wins. Older records do not have one, so they use a
	/// UUID-derived fallback that is stable across launches without putting any
	/// card or document data into the visual choice.
	static func paletteColor(for palette: CardPalette?, identifier: UUID) -> Color {
		guard let palette else {
			return paletteColor(for: identifier)
		}

		switch palette {
		case .emerald:
			return Color(red: 0.132, green: 0.389, blue: 0.227)
		case .forest:
			return Color(red: 0.071, green: 0.286, blue: 0.243)
		case .ink:
			return Color(red: 0.114, green: 0.310, blue: 0.500)
		case .berry:
			return Color(red: 0.435, green: 0.235, blue: 0.337)
		case .amber:
			return Color(red: 0.419, green: 0.333, blue: 0.105)
		}
	}
}

extension View {
	/// Gives card and document controls a consistent, sufficiently large target.
	func holderTapTarget() -> some View {
		contentShape(Rectangle())
			.frame(minHeight: 44)
	}

	func holderSurface(
		_ colorScheme: ColorScheme,
		cornerRadius: CGFloat = HolderTheme.deckCornerRadius
	) -> some View {
		background(HolderTheme.raisedSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
				.stroke(HolderTheme.separator(for: colorScheme), lineWidth: 1)
		}
	}
}
