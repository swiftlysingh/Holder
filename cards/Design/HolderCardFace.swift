//
//  HolderCardFace.swift
//  Holder
//
//  The card surface is deliberately a render, rather than a form: it keeps
//  sensitive fields masked until a person makes an explicit, short-lived
//  reveal request.
//

import SwiftUI

struct HolderCardFace: View {
	let card: CardData
	let isLocked: Bool
	let isNumberRevealed: Bool
	let isHolderRevealed: Bool
	let isExpirationRevealed: Bool
	let isShowingBack: Bool
	let copiedField: CardSensitiveField?
	let onRequestUnlock: () -> Void
	let onNumber: () -> Void
	let onHolder: () -> Void
	let onExpiration: () -> Void
	let onSecurityCode: () -> Void
	let onFlip: () -> Void

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private var title: String {
		card.displayLabel
	}

	private var maskedNumber: String {
		let compact = card.number.replacingOccurrences(of: " ", with: "")
		let tail = String(compact.suffix(4))
		return tail.isEmpty ? "•••• •••• •••• ••••" : "•••• •••• •••• \(tail)"
	}

	var body: some View {
		ZStack(alignment: .topLeading) {
			RoundedRectangle(cornerRadius: HolderTheme.deckCornerRadius, style: .continuous)
				.fill(HolderTheme.paletteColor(for: card.palette, identifier: card.id))

			if isShowingBack {
				back
			} else {
				front
			}
		}
		.frame(maxWidth: .infinity)
		.frame(minHeight: 204)
		.shadow(color: .black.opacity(0.22), radius: 15, y: 8)
		.contentShape(RoundedRectangle(cornerRadius: HolderTheme.deckCornerRadius, style: .continuous))
		.onTapGesture(perform: onFlip)
		.accessibilityElement(children: .contain)
		.accessibilityLabel("\(title) card")
		.accessibilityHint(isLocked ? "Unlock Holder before viewing sensitive details." : "Double tap to \(isShowingBack ? "hide" : "show") the security code.")
		.accessibilityAction(named: isShowingBack ? "Hide security code" : "Show security code") {
			onFlip()
		}
		.animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: isShowingBack)
	}

	private var front: some View {
		VStack(alignment: .leading, spacing: 0) {
			HStack(alignment: .top) {
				VStack(alignment: .leading, spacing: 4) {
					Text(title)
						.font(.headline.weight(.semibold))
						.lineLimit(1)
					Text(card.type.rawValue.uppercased())
						.font(.caption2.weight(.semibold))
						.tracking(0.8)
						.foregroundStyle(.white.opacity(0.65))
				}
				Spacer(minLength: 12)
				networkMark
			}

			credentialMark
				.padding(.top, 23)

			Spacer(minLength: 12)

			fieldButton(
				text: isNumberRevealed ? card.number : maskedNumber,
				field: .number,
				isVisible: isNumberRevealed,
				label: "Card number",
				action: onNumber
			)

				HStack(alignment: .bottom, spacing: 14) {
					fieldButton(
						text: isHolderRevealed ? card.name.uppercased() : "••••••",
						field: .holderName,
						isVisible: isHolderRevealed,
					label: "Cardholder name",
					action: onHolder,
					isCompact: true
				)
				Spacer(minLength: 8)
				fieldButton(
					text: isExpirationRevealed ? card.expiration : "••/••",
					field: .expiration,
					isVisible: isExpirationRevealed,
					label: "Expiration date",
					action: onExpiration,
					isCompact: true
				)
				Text("CVV •••")
					.font(.caption.monospacedDigit())
					.foregroundStyle(.white.opacity(0.72))
			}
		}
		.padding(20)
		.foregroundStyle(.white)
	}

	private var back: some View {
		VStack(alignment: .leading, spacing: 18) {
			HStack {
				Text(title)
					.font(.headline.weight(.semibold))
					.lineLimit(1)
				Spacer()
				Text("CARD BACK")
					.font(.caption2.weight(.semibold))
					.tracking(0.8)
					.foregroundStyle(.white.opacity(0.65))
			}
			Rectangle()
				.fill(.black.opacity(0.74))
				.frame(height: 38)
				.padding(.horizontal, -20)
			VStack(alignment: .leading, spacing: 8) {
				Text("SECURITY CODE")
					.font(.caption2.weight(.semibold))
					.foregroundStyle(.white.opacity(0.66))
				fieldButton(
					text: isLocked ? "•••" : card.cvv,
					field: .securityCode,
					isVisible: !isLocked,
					label: "Security code",
					action: onSecurityCode,
					isCompact: true
				)
			}
			Spacer()
			Text("Tap card to return to the front")
				.font(.caption)
				.foregroundStyle(.white.opacity(0.68))
		}
		.padding(20)
		.foregroundStyle(.white)
	}

	private var networkMark: some View {
		Group {
			if card.type == .loyaltyCard {
				Text("LOYALTY")
					.font(.caption2.weight(.bold))
					.tracking(0.5)
			} else if card.type == .travelCard {
				Text("TRAVEL")
					.font(.caption2.weight(.bold))
					.tracking(0.5)
			} else if card.network == .other {
				Image(systemName: "creditcard.fill")
					.font(.title3)
			} else {
				Text(card.network.rawValue.uppercased())
					.font(.caption2.weight(.bold))
					.tracking(0.5)
			}
		}
		.foregroundStyle(.white.opacity(0.88))
		.padding(.horizontal, 8)
		.padding(.vertical, 5)
		.overlay {
			RoundedRectangle(cornerRadius: 6, style: .continuous)
				.stroke(.white.opacity(0.45), lineWidth: 1)
		}
	}

	@ViewBuilder
	private var credentialMark: some View {
		if card.type == .loyaltyCard || card.type == .travelCard {
			Image(systemName: "barcode")
				.font(.title2.weight(.medium))
				.frame(width: 42, height: 27)
				.background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
				.accessibilityHidden(true)
		} else {
			RoundedRectangle(cornerRadius: 5, style: .continuous)
				.fill(Color(red: 0.831, green: 0.686, blue: 0.369))
				.frame(width: 34, height: 25)
				.overlay {
					RoundedRectangle(cornerRadius: 5, style: .continuous)
						.stroke(Color(red: 0.651, green: 0.496, blue: 0.235), lineWidth: 1)
				}
				.accessibilityHidden(true)
		}
	}

	private func fieldButton(
		text: String,
		field: CardSensitiveField,
		isVisible: Bool,
		label: String,
		action: @escaping () -> Void,
		isCompact: Bool = false
	) -> some View {
		Button(action: action) {
			HStack(spacing: 6) {
				Text(text.isEmpty ? "—" : text)
					.font(isCompact ? .caption.monospacedDigit() : .body.monospacedDigit())
					.lineLimit(1)
				Image(systemName: copiedField == field ? "checkmark" : "doc.on.doc")
					.font(.caption2.weight(.semibold))
					.foregroundStyle(.white.opacity(isVisible ? 0.88 : 0.56))
			}
			.padding(.horizontal, isCompact ? 0 : 4)
			.padding(.vertical, 6)
			.background(isVisible ? .white.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
		}
		.buttonStyle(.plain)
		.contentShape(Rectangle())
			.frame(minHeight: 44)
			.accessibilityLabel(copiedField == field ? "\(label) copied" : label)
			.accessibilityValue(isVisible ? (text.isEmpty ? "Empty" : text) : "Hidden")
			.accessibilityHint(isLocked ? "Unlock Holder to copy this field." : isVisible ? "Copies \(label.lowercased())." : "Copies \(label.lowercased()) and reveals it for 12 seconds.")
	}
}

enum HolderDeckArtwork {
	case card(
		palette: CardPalette?,
		type: CardType,
		network: CardNetwork,
		maskedTail: String
	)
	case document(
		palette: CardPalette?,
		kind: DocumentKind,
		photoCount: Int
	)
}

/// The home deck deliberately reads as a stack of passes, not a list of rows.
/// Its card surface carries only the safe label, type/network cues, and a
/// masked tail; document art never renders an attachment image.
struct HolderDeckCard: View {
	let title: String
	let identifier: UUID
	let isFavorite: Bool
	let artwork: HolderDeckArtwork
	let action: () -> Void

	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		Button(action: action) {
			ZStack {
				background
				artworkContent
			}
			.frame(maxWidth: .infinity, alignment: .topLeading)
			.frame(height: 120, alignment: .topLeading)
			.clipShape(RoundedRectangle(cornerRadius: HolderTheme.deckCornerRadius, style: .continuous))
			.overlay {
				RoundedRectangle(cornerRadius: HolderTheme.deckCornerRadius, style: .continuous)
					.stroke(borderColor, lineWidth: 1)
			}
			.overlay(alignment: .bottomTrailing) {
				if isFavorite {
					Image(systemName: "star.fill")
						.font(.caption.weight(.bold))
						.foregroundStyle(favoriteColor)
						.padding(14)
						.accessibilityHidden(true)
				}
			}
		}
		.buttonStyle(.plain)
		.contentShape(RoundedRectangle(cornerRadius: HolderTheme.deckCornerRadius, style: .continuous))
		.accessibilityLabel(accessibilityDescription + (isFavorite ? ", favorite" : ""))
		.accessibilityHint("Opens details.")
	}

	@ViewBuilder
	private var background: some View {
		switch artwork {
		case .card(let palette, _, _, _):
			HolderTheme.paletteColor(for: palette, identifier: identifier)
				.overlay(alignment: .bottomTrailing) {
					Circle()
						.fill(.white.opacity(0.08))
						.frame(width: 142, height: 142)
						.offset(x: 38, y: 52)
				}
		case .document:
			HolderTheme.raisedSurface(for: colorScheme)
		}
	}

	@ViewBuilder
	private var artworkContent: some View {
		switch artwork {
		case let .card(_, type, network, maskedTail):
			cardArtwork(type: type, network: network, maskedTail: maskedTail)
		case let .document(palette, kind, photoCount):
			documentArtwork(palette: palette, kind: kind, photoCount: photoCount)
		}
	}

	private var borderColor: Color {
		switch artwork {
		case .card:
			return .white.opacity(0.14)
		case .document:
			return HolderTheme.separator(for: colorScheme)
		}
	}

	private var favoriteColor: Color {
		switch artwork {
		case .card:
			return .white
		case .document:
			return HolderTheme.paletteColor(for: nil, identifier: identifier)
		}
	}

	private var accessibilityDescription: String {
		switch artwork {
		case let .card(_, type, network, maskedTail):
			let tailDescription = maskedTail == "Details masked"
				? "Number hidden"
				: "Masked number \(maskedTail)"
			return "\(title), \(type.rawValue), \(network.rawValue), \(tailDescription)"
		case let .document(_, kind, photoCount):
			let photoDescription = photoCount == 1 ? "1 encrypted photo" : "\(photoCount) encrypted photos"
			return "\(title), \(kind.rawValue) document, \(photoDescription)"
		}
	}

	private func cardArtwork(
		type: CardType,
		network: CardNetwork,
		maskedTail: String
	) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			HStack(alignment: .top, spacing: 12) {
				Text(title)
					.font(.subheadline.weight(.semibold))
					.lineLimit(1)
				Spacer(minLength: 8)
				networkMark(for: network)
			}

			Spacer(minLength: 8)

			HStack(alignment: .bottom) {
				cardChip
				Spacer(minLength: 12)
				Text(maskedTail)
					.font(.caption.monospacedDigit().weight(.medium))
					.lineLimit(1)
					.foregroundStyle(.white.opacity(0.82))
			}

			Text(type.rawValue.uppercased())
				.font(.caption2.weight(.semibold))
				.tracking(0.65)
				.lineLimit(1)
			.foregroundStyle(.white.opacity(0.66))
			.padding(.top, 7)
		}
		.padding(14)
		.foregroundStyle(.white)
	}

	private func documentArtwork(
		palette: CardPalette?,
		kind: DocumentKind,
		photoCount: Int
	) -> some View {
		let accent = HolderTheme.paletteColor(for: palette, identifier: identifier)
		return HStack(alignment: .top, spacing: 13) {
			documentPhotoCue(accent: accent, photoCount: photoCount)
			VStack(alignment: .leading, spacing: 5) {
				Text(title)
					.font(.subheadline.weight(.semibold))
					.lineLimit(1)
				Text(kind.rawValue.uppercased())
					.font(.caption2.weight(.semibold))
					.tracking(0.55)
					.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
					.lineLimit(1)
				Spacer(minLength: 5)
				HStack(spacing: 5) {
					Image(systemName: photoCount > 0 ? "lock.fill" : "camera")
						.font(.caption2.weight(.semibold))
					Text(photoDescription(photoCount))
						.font(.caption2.weight(.semibold))
						.lineLimit(1)
				}
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
			}
			Spacer(minLength: 0)
		}
		.padding(14)
	}

	private func documentPhotoCue(accent: Color, photoCount: Int) -> some View {
		ZStack(alignment: .bottomTrailing) {
			RoundedRectangle(cornerRadius: 8, style: .continuous)
				.fill(accent.opacity(colorScheme == .dark ? 0.34 : 0.18))
				.frame(width: 46, height: 57)
				.overlay {
					Image(systemName: photoCount > 0 ? "photo.fill" : "doc.text.image")
						.font(.title3.weight(.semibold))
						.foregroundStyle(accent)
				}
			if photoCount > 1 {
				RoundedRectangle(cornerRadius: 5, style: .continuous)
					.fill(HolderTheme.raisedSurface(for: colorScheme))
					.frame(width: 18, height: 20)
					.overlay {
						Image(systemName: "photo")
							.font(.caption2.weight(.bold))
							.foregroundStyle(accent)
					}
					.overlay {
						RoundedRectangle(cornerRadius: 5, style: .continuous)
							.stroke(accent.opacity(0.5), lineWidth: 1)
					}
					.offset(x: 6, y: 5)
			}
		}
		.frame(width: 52, height: 62, alignment: .topLeading)
		.accessibilityHidden(true)
	}

	private var cardChip: some View {
		RoundedRectangle(cornerRadius: 4, style: .continuous)
			.fill(Color(red: 0.831, green: 0.686, blue: 0.369))
			.frame(width: 28, height: 21)
			.overlay {
				RoundedRectangle(cornerRadius: 4, style: .continuous)
					.stroke(Color(red: 0.651, green: 0.496, blue: 0.235), lineWidth: 1)
			}
			.overlay {
				Rectangle()
					.fill(Color(red: 0.651, green: 0.496, blue: 0.235).opacity(0.65))
					.frame(height: 1)
			}
			.accessibilityHidden(true)
	}

	@ViewBuilder
	private func networkMark(for network: CardNetwork) -> some View {
		switch network {
		case .master:
			HStack(spacing: -5) {
				Circle().fill(Color(red: 0.922, green: 0, blue: 0.106))
				Circle().fill(Color(red: 0.969, green: 0.620, blue: 0.106))
			}
			.frame(width: 25, height: 15)
		case .other:
			Image(systemName: "creditcard.fill")
				.font(.caption.weight(.bold))
		default:
			Text(network.rawValue.uppercased())
				.font(.caption2.weight(.bold))
				.tracking(0.45)
		}
	}

	private func photoDescription(_ photoCount: Int) -> String {
		switch photoCount {
		case 0:
			return "NO PHOTOS"
		case 1:
			return "1 ENCRYPTED PHOTO"
		default:
			return "\(photoCount) ENCRYPTED PHOTOS"
		}
	}
}
