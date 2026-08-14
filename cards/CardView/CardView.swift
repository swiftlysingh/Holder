//
//  CardView.swift
//  Holder
//

import SinghDevKit
import SwiftUI

#if os(macOS)
import AppKit
#else
import PhotosUI
import UIKit
#endif

struct CardView: View {
	@StateObject private var model: CardViewModel
	private let onArchive: ((CardData) -> Bool)?
	private let onDelete: ((CardData) -> Bool)?
	private let onMigrateLegacyImage: ((CardData, DocumentKind) -> Result<DocumentData, LegacyImageMigrationError>)?

	@Environment(\.analytics) private var analytics
	@Environment(\.dismiss) private var dismiss
	@Environment(\.scenePhase) private var scenePhase
	@Environment(\.colorScheme) private var colorScheme
	@AppStorage("isAuthEnabled") private var isAuthEnabled = true
	@AppStorage("timeout") private var authTimeout = 60
	@State private var showArchiveConfirmation = false
	@State private var showDeleteConfirmation = false
	@State private var showMigrationKindChooser = false
	@State private var isMigratingLegacyImage = false
	#if os(iOS)
	@State private var cardScannerRequest: CardScannerRequest?
	#endif

	init(
		model: CardViewModel,
		onArchive: ((CardData) -> Bool)? = nil,
		onDelete: ((CardData) -> Bool)? = nil,
		onMigrateLegacyImage: ((CardData, DocumentKind) -> Result<DocumentData, LegacyImageMigrationError>)? = nil
	) {
		_model = StateObject(wrappedValue: model)
		self.onArchive = onArchive
		self.onDelete = onDelete
		self.onMigrateLegacyImage = onMigrateLegacyImage
	}

	var body: some View {
		Group {
			#if os(macOS)
			macOSCardView
			#else
			iosCardView
			#endif
		}
		.background(HolderTheme.background(for: colorScheme).ignoresSafeArea())
		.onAppear {
			// The card gate runs on every detail/editor presentation. When the owner
			// disabled card authentication this resolves immediately without a prompt.
			model.authenticateUser()
		}
		.onChange(of: model.isAuthenticated) { _, authenticated in
			if authenticated { refreshAuthenticationTimeout() }
		}
		.onChange(of: model.card) {
			// Typing in the editor is user activity too, not only tapping a field.
			refreshAuthenticationTimeout()
		}
		.onChange(of: scenePhase) { _, phase in
			if phase == .active {
				model.resolveScheduledLockOnActive()
				refreshAuthenticationTimeout()
			} else {
				// A reveal session never survives leaving the foreground, even when the
				// longer app-level auth timeout has not elapsed yet.
				model.hideSensitiveValues()
				if phase == .background && model.isAuthenticating {
					// A system authentication prompt can make the scene inactive, but a
					// real background transition must invalidate that attempt immediately.
					model.lock()
				} else if isAuthEnabled && !model.isAuthenticating {
					model.scheduleLock(after: .seconds(authTimeout))
				}
			}
		}
		.onChange(of: isAuthEnabled) { _, enabled in
			if enabled {
				model.lock()
			} else {
				model.authenticateUser()
			}
		}
		.onDisappear {
			model.lock()
			model.discardLegacyImageChanges()
		}
		.simultaneousGesture(TapGesture().onEnded { _ in refreshAuthenticationTimeout() })
		.alert("Archive this card?", isPresented: $showArchiveConfirmation) {
			Button("Archive", role: .destructive, action: archiveCard)
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("You can restore it from Archived.")
		}
		.alert("Delete this card?", isPresented: $showDeleteConfirmation) {
			Button("Delete", role: .destructive, action: deleteCard)
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("This removes the card from Holder. Legacy Other Card images are removed from iCloud first.")
		}
		.alert("Card error", isPresented: $model.showErrorAlert) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(model.errorMessage ?? "Holder could not complete that action.")
		}
		.confirmationDialog(
			"Move to encrypted document",
			isPresented: $showMigrationKindChooser,
			titleVisibility: .visible
		) {
			ForEach(DocumentKind.allCases) { kind in
				Button(kind.rawValue) { migrateLegacyImage(as: kind) }
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("Choose the document type. Holder encrypts and verifies the photo on this device before removing the legacy card and iCloud image.")
		}
		.sdkScreen(model.isEditing ? AppAnalyticsScreen.cardEditor : AppAnalyticsScreen.cardDetails)
	}

	/// A fixed, five-slot palette control. `nil` continues to mean the legacy
	/// automatic appearance until a person deliberately picks a color.
	private var cardPalettePicker: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("CARD COLOR")
				.font(.caption.weight(.semibold))
				.tracking(0.7)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))

			HStack(spacing: 12) {
				ForEach(CardPalette.allCases) { palette in
					paletteSwatch(
						palette,
						isSelected: model.card.palette == palette,
						hint: "Sets this card's color."
					) {
						model.card.palette = palette
					}
				}
			}
		}
		.padding(14)
		.holderSurface(colorScheme)
		.accessibilityElement(children: .contain)
		.accessibilityLabel("Card color")
	}

	private func paletteSwatch(
		_ palette: CardPalette,
		isSelected: Bool,
		hint: String,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			Circle()
				.fill(HolderTheme.paletteColor(for: palette, identifier: model.card.id))
				.frame(width: 34, height: 34)
				.overlay {
					if isSelected {
						Image(systemName: "checkmark")
							.font(.caption.weight(.bold))
							.foregroundStyle(palette == .amber ? HolderTheme.ink : .white)
					}
				}
				.overlay {
					Circle()
						.stroke(
							isSelected ? HolderTheme.primaryText(for: colorScheme) : .white.opacity(0.72),
							lineWidth: isSelected ? 2 : 1
						)
				}
				.frame(width: 44, height: 44)
		}
		.buttonStyle(.plain)
		.accessibilityLabel("\(palette.rawValue.capitalized) card color")
		.accessibilityValue(isSelected ? "Selected" : "Not selected")
		.accessibilityHint(hint)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}

	#if !os(macOS)
	private var iosCardView: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				if model.isEditing {
					cardEditor
				} else {
					cardDetails
				}
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 18)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.scrollIndicators(.hidden)
		.interactiveDismissDisabled(model.hasUnresolvedLegacyImageMutation)
		.navigationTitle(model.isAddNewFlow ? "New card" : cardTitle)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			if model.isAddNewFlow {
				ToolbarItem(placement: .topBarLeading) {
					Button("Cancel") { dismiss() }
						.holderTapTarget()
						.disabled(model.hasUnresolvedLegacyImageMutation)
				}
			}

			ToolbarItem(placement: .topBarTrailing) {
				if model.isEditing {
					Button("Done", action: finishEditing)
						.holderTapTarget()
						.disabled(!model.isAuthenticated || model.isAuthenticating)
				} else {
					Menu {
						Button("Edit", systemImage: "pencil") {
							if model.isAuthenticated {
								model.isEditing = true
							} else {
								requestUnlock()
							}
						}
						if model.isAuthenticated, onArchive != nil {
							Button("Archive", systemImage: "archivebox") {
								showArchiveConfirmation = true
							}
						}
						if model.isAuthenticated, onDelete != nil {
							Divider()
							Button("Delete", systemImage: "trash", role: .destructive) {
								showDeleteConfirmation = true
							}
						}
					} label: {
						Label("Card actions", systemImage: "ellipsis.circle")
					}
					.holderTapTarget()
				}
			}

			#if os(iOS)
				if model.isEditing && model.isAddNewFlow {
					ToolbarItem(placement: .topBarLeading) {
						Button(action: beginCardScan) {
							Label("Scan card", systemImage: "camera.viewfinder")
						}
						.holderTapTarget()
				}
			}
			#endif
		}
		#if os(iOS)
		.fullScreenCover(item: $cardScannerRequest) { request in
			SharkCardScanViewRepresentable(
				noPermissionAction: { track(.cardScanPermissionDenied) },
				successHandler: { response in
					Task { @MainActor in
						guard cardScannerRequest?.id == request.id else { return }
						defer { cardScannerRequest = nil }
						guard model.applyScannerResult(
							number: response.number,
							holder: response.holder,
							expiration: response.expiry,
							authenticationGeneration: request.authenticationGeneration
						) else { return }
						track(.cardScanCompleted)
					}
				}
			)
			.sdkScreen(AppAnalyticsScreen.cardScanner)
		}
		#endif
	}

	#if os(iOS)
	private func beginCardScan() {
		guard model.isAuthenticated, model.isEditing, model.isAddNewFlow else {
			requestUnlock()
			return
		}
		track(.cardScanStarted)
		cardScannerRequest = CardScannerRequest(
			authenticationGeneration: model.authenticationGeneration
		)
	}
	#endif

	private var cardDetails: some View {
		VStack(alignment: .leading, spacing: 18) {
			if !model.isAuthenticated {
				unlockNotice
			}

			ZStack(alignment: .top) {
				HolderCardFace(
					card: model.card,
					isLocked: !model.isAuthenticated,
					isNumberRevealed: model.isRevealed(.number),
					isHolderRevealed: model.isRevealed(.holderName),
					isExpirationRevealed: model.isRevealed(.expiration),
					isShowingBack: model.isShowingBack,
					copiedField: model.copiedField,
					onRequestUnlock: requestUnlock,
					onNumber: { handleSensitiveField(.number) },
					onHolder: { handleSensitiveField(.holderName) },
					onExpiration: { handleSensitiveField(.expiration) },
					onSecurityCode: { handleSensitiveField(.securityCode) },
					onFlip: handleFlip
				)
				.privacySensitive()

				if let copiedField = model.copiedField {
					copiedToast(for: copiedField)
						.offset(y: -20)
				}
			}

			Text(model.isShowingBack ? "Tap the security code to copy. Tap the card to return to the front." : "Tap a field to copy it and reveal it for 12 seconds. Tap the card for its security code.")
				.font(.footnote)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
				.frame(maxWidth: .infinity, alignment: .center)
				.multilineTextAlignment(.center)

			if model.revealedField != nil {
				TimelineView(.periodic(from: .now, by: 1)) { context in
					if let seconds = model.remainingRevealSeconds(at: context.date) {
						Label("Hides in \(seconds)s", systemImage: "timer")
							.font(.caption.weight(.semibold))
							.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
							.accessibilityLabel("Sensitive field hides in \(seconds) seconds")
					}
				}
				.frame(maxWidth: .infinity)
			}

			if !model.card.description.isEmpty {
				infoSection(title: "About", value: model.card.description)
			}

			if model.isAuthenticated, model.card.type == .otherCard, let image = model.cardImage {
				legacyImageSection(image)
					.privacySensitive()
			}

			if model.isAuthenticated, (canOfferLegacyMigration || onArchive != nil || onDelete != nil) {
				managementSection
			}
		}
	}

	private var unlockNotice: some View {
		HStack(alignment: .top, spacing: 12) {
			Image(systemName: "lock.fill")
				.foregroundStyle(HolderTheme.mintInk)
				.frame(width: 26, height: 26)
				.background(HolderTheme.mint, in: Circle())
			VStack(alignment: .leading, spacing: 4) {
				Text("Details are masked")
					.font(.subheadline.weight(.semibold))
				Text("Unlock with Face ID, Touch ID, or your device passcode to reveal fields temporarily.")
					.font(.footnote)
					.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
			}
			Spacer(minLength: 8)
			Button(action: requestUnlock) {
				if model.isAuthenticating {
					ProgressView()
				} else {
					Text("Unlock")
				}
			}
			.buttonStyle(.borderedProminent)
			.tint(HolderTheme.brandRaised)
			.disabled(model.isAuthenticating)
			.holderTapTarget()
		}
		.padding(14)
		.holderSurface(colorScheme)
	}

	private var cardEditor: some View {
		VStack(alignment: .leading, spacing: 16) {
			if !model.isAuthenticated {
				unlockNotice
			} else {
				Text(model.isAddNewFlow ? "Save a card" : "Edit card")
					.font(.title2.weight(.bold))
					.foregroundStyle(HolderTheme.primaryText(for: colorScheme))

				Text("Cards use the system Keychain and may follow your iCloud Keychain settings. Photos belong in encrypted document items, not here.")
					.font(.footnote)
					.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))

				VStack(spacing: 0) {
					editorRow("Card label") {
						TextField("e.g. Daily Visa", text: $model.card.description)
							.multilineTextAlignment(.trailing)
					}
					Divider()
					editorRow("Cardholder") {
						TextField("Name on card", text: $model.card.name)
							.multilineTextAlignment(.trailing)
					}
					Divider()
					editorRow("Card number") {
						TextField("1234 5678 9012 3456", text: $model.card.number)
							.multilineTextAlignment(.trailing)
							.keyboardType(.numbersAndPunctuation)
					}
					Divider()
					editorRow("Expiration") {
						TextField("MM/YY", text: $model.card.expiration)
							.multilineTextAlignment(.trailing)
							.keyboardType(.numberPad)
							.onChange(of: model.card.expiration) { _, value in
								formatExpirationIfNeeded(value)
							}
					}
					Divider()
					editorRow("Security code") {
						SecureField("CVV", text: $model.card.cvv)
							.multilineTextAlignment(.trailing)
							.keyboardType(.numberPad)
					}
				}
				.holderSurface(colorScheme)
				.privacySensitive()

				VStack(spacing: 0) {
					Picker("Card type", selection: $model.card.type) {
						ForEach(CardType.allCases) { type in
							Text(type.rawValue).tag(type)
						}
					}
					.padding(14)
					Divider()
					if model.card.type != .otherCard {
						Picker("Network", selection: $model.card.network) {
							ForEach(CardNetwork.allCases) { network in
								Text(network.rawValue).tag(network)
							}
						}
						.padding(14)
					}
				}
				.holderSurface(colorScheme)

				cardPalettePicker

				if model.card.type == .otherCard {
					legacyImageEditor
				}
			}
		}
	}

	private func editorRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 12) {
			Text(label)
				.font(.subheadline)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
				.frame(maxWidth: 112, alignment: .leading)
			content()
				.font(.body)
				.foregroundStyle(HolderTheme.primaryText(for: colorScheme))
		}
		.padding(14)
		.frame(minHeight: 52)
	}

	private func infoSection(title: String, value: String) -> some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title.uppercased())
				.font(.caption.weight(.semibold))
				.tracking(0.7)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
			Text(value)
				.font(.body)
				.foregroundStyle(HolderTheme.primaryText(for: colorScheme))
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(16)
		.holderSurface(colorScheme)
	}

		private func legacyImageSection(_ image: UIImage) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("LEGACY CARD IMAGE")
				.font(.caption.weight(.semibold))
				.tracking(0.7)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
			Image(uiImage: image)
				.resizable()
				.scaledToFit()
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
			Text("Legacy Other Card images remain in iCloud Drive. New document photos are encrypted and stored on this device.")
				.font(.footnote)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
		}
		.padding(16)
		.holderSurface(colorScheme)
	}

	private var legacyImageEditor: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("LEGACY CARD IMAGE")
				.font(.caption.weight(.semibold))
				.tracking(0.7)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
			PhotosPicker(selection: $model.selectedItem, matching: .images) {
				Label(model.cardImage == nil ? "Add legacy card image" : "Replace legacy card image", systemImage: "photo")
					.frame(maxWidth: .infinity, minHeight: 44)
			}
			.buttonStyle(.bordered)
			.onChange(of: model.selectedItem) { _, selection in
				let authenticationGeneration = model.authenticationGeneration
				Task {
					do {
						guard let data = try await selection?.loadTransferable(type: Data.self),
							let image = UIImage(data: data) else {
							throw URLError(.cannotCreateFile)
						}
						guard model.stageLegacyImage(
							image,
							authenticationGeneration: authenticationGeneration
						) else { return }
					} catch {
						guard authenticationGeneration == model.authenticationGeneration,
							model.isAuthenticated else { return }
						model.errorMessage = "Unable to save the legacy card image."
						model.showErrorAlert = true
					}
				}
			}
			if model.cardImage != nil {
				Button("Remove legacy card image", systemImage: "trash", role: .destructive) {
					model.stageLegacyImageRemoval()
				}
				.frame(minHeight: 44)
			}
			Text("This compatibility image uses iCloud Drive, not the encrypted document vault. Changes are saved only when you tap Done.")
				.font(.footnote)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
		}
		.padding(16)
		.holderSurface(colorScheme)
	}
		#endif

	private var managementSection: some View {
		VStack(spacing: 0) {
			if canOfferLegacyMigration {
				Button("Move to encrypted document", systemImage: "lock.doc") {
					showMigrationKindChooser = true
				}
				.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
				.padding(.horizontal, 16)
				.disabled(isMigratingLegacyImage)
				.accessibilityHint("Choose a document type, encrypt and verify the image, then remove the legacy card.")
			}
			if canOfferLegacyMigration, onArchive != nil || onDelete != nil { Divider() }
			if onArchive != nil {
				Button("Archive card", systemImage: "archivebox") {
					showArchiveConfirmation = true
				}
				.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
				.padding(.horizontal, 16)
			}
			if onArchive != nil, onDelete != nil { Divider() }
			if onDelete != nil {
				Button("Delete card", systemImage: "trash", role: .destructive) {
					showDeleteConfirmation = true
				}
				.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
				.padding(.horizontal, 16)
			}
		}
		.holderSurface(colorScheme)
	}

	private var canOfferLegacyMigration: Bool {
		model.card.type == .otherCard
			&& onMigrateLegacyImage != nil
			&& (model.cardImage != nil || model.card.hasLegacyImage != false)
	}

	private func copiedToast(for field: CardSensitiveField) -> some View {
		Label("\(field.accessibilityName.capitalized) copied", systemImage: "checkmark.circle.fill")
			.font(.subheadline.weight(.semibold))
			.foregroundStyle(HolderTheme.primaryText(for: colorScheme))
			.padding(.horizontal, 14)
			.padding(.vertical, 9)
			.background(HolderTheme.raisedSurface(for: colorScheme), in: Capsule())
			.overlay {
				Capsule().stroke(HolderTheme.separator(for: colorScheme), lineWidth: 1)
			}
			.shadow(color: .black.opacity(0.18), radius: 10, y: 4)
			.accessibilityLabel("\(field.accessibilityName.capitalized) copied")
	}

	private var cardTitle: String {
		model.card.displayLabel
	}

	private func requestUnlock() {
		guard !model.isAuthenticating else { return }
		model.authenticateUser()
	}

	private func refreshAuthenticationTimeout() {
		guard isAuthEnabled, model.isAuthenticated else { return }
		model.scheduleLock(after: .seconds(authTimeout))
	}

	private func handleSensitiveField(_ field: CardSensitiveField) {
		guard model.isAuthenticated else {
			requestUnlock()
			return
		}
		let value: String
		switch field {
		case .number: value = model.card.number
		case .expiration: value = model.card.expiration
		case .securityCode: value = model.card.cvv
		case .holderName: value = model.card.name
		}
		model.reveal(field)
		model.copyAction(with: value, field: field)
		UserSettings.shared.requestReview()
	}

	private func handleFlip() {
		guard model.isAuthenticated else {
			requestUnlock()
			return
		}
		model.flipCard()
	}

	private func formatExpirationIfNeeded(_ value: String) {
		if value.count == 2 && !value.contains("/") {
			model.card.expiration = value + "/"
		} else if value.count > 5 {
			model.card.expiration = String(value.prefix(5))
		}
	}

	private func finishEditing() {
		guard model.isAuthenticated else {
			requestUnlock()
			return
		}
		guard model.card.type == .otherCard || !model.card.number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			model.errorMessage = "Enter a card number before saving."
			model.showErrorAlert = true
			return
		}

		let operation: AppAnalyticsEvent.SaveOperation = model.isAddNewFlow ? .create : .update
		let inputMethod: AppAnalyticsEvent.InputMethod = model.didUseScanner ? .scanner : .manual
		model.stageLegacyImageRemovalIfNoLongerNeeded()
		guard model.persistLegacyImageMutationMarkerForSave() else {
			model.errorMessage = "Holder could not create a durable cleanup marker for the legacy iCloud image. No image change was made; keep this editor open and retry Done."
			model.showErrorAlert = true
			track(.cardSaveFailed(operation: operation, inputMethod: inputMethod))
			return
		}
		guard model.applyLegacyImageChangesForSave() else {
			model.errorMessage = "Holder could not update the legacy iCloud image. Its durable cleanup marker remains saved; keep this editor open and retry Done."
			model.showErrorAlert = true
			track(.cardSaveFailed(operation: operation, inputMethod: inputMethod))
			return
		}
		guard model.addUpdateCard(model.card) else {
			model.errorMessage = "Holder could not finish saving this card. Its durable cleanup marker remains saved, so the legacy image cannot become orphaned; retry Done."
			model.showErrorAlert = true
			track(.cardSaveFailed(operation: operation, inputMethod: inputMethod))
			return
		}
		model.finalizeLegacyImageChangesAfterSave()
		track(.cardSaveCompleted(operation: operation, inputMethod: inputMethod))
		model.isEditing = false
		if model.isAddNewFlow {
			dismiss()
		}
	}

	private func archiveCard() {
		guard model.isAuthenticated else {
			requestUnlock()
			return
		}
		guard let onArchive, onArchive(model.card) else {
			model.errorMessage = "Unable to archive this card. Try again."
			model.showErrorAlert = true
			return
		}
		dismiss()
	}

	private func deleteCard() {
		guard model.isAuthenticated else {
			requestUnlock()
			return
		}
		guard let onDelete, onDelete(model.card) else {
			model.errorMessage = "Unable to delete this card. Try again."
			model.showErrorAlert = true
			return
		}
		dismiss()
	}

	private func migrateLegacyImage(as kind: DocumentKind) {
		guard model.isAuthenticated else {
			requestUnlock()
			return
		}
		guard let onMigrateLegacyImage else { return }
		isMigratingLegacyImage = true
		defer { isMigratingLegacyImage = false }

		switch onMigrateLegacyImage(model.card, kind) {
		case .success:
			track(.legacyCardMigrationCompleted)
			dismiss()
		case .failure(let error):
			track(.legacyCardMigrationFailed)
			model.errorMessage = error.localizedDescription
			model.showErrorAlert = true
		}
	}

	private func track(_ event: AppAnalyticsEvent) {
		Task { await analytics.capture(event) }
	}

	#if os(macOS)
	private var macOSCardView: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				if !model.isAuthenticated {
					macOSUnlockNotice
				}
				HolderCardFace(
					card: model.card,
					isLocked: !model.isAuthenticated,
					isNumberRevealed: model.isRevealed(.number),
					isHolderRevealed: model.isRevealed(.holderName),
					isExpirationRevealed: model.isRevealed(.expiration),
					isShowingBack: model.isShowingBack,
					copiedField: model.copiedField,
					onRequestUnlock: requestUnlock,
					onNumber: { handleSensitiveField(.number) },
					onHolder: { handleSensitiveField(.holderName) },
					onExpiration: { handleSensitiveField(.expiration) },
					onSecurityCode: { handleSensitiveField(.securityCode) },
					onFlip: handleFlip
				)
				.privacySensitive()
				if model.isEditing, model.isAuthenticated {
					macOSEditor
				} else if !model.card.description.isEmpty {
					macOSInfoSection(title: "About", value: model.card.description)
				}
			}
			.padding(24)
			.frame(maxWidth: 520)
			.frame(maxWidth: .infinity)
		}
		.navigationTitle(cardTitle)
		.toolbar {
			if model.isEditing {
				Button("Done", action: finishEditing)
					.disabled(!model.isAuthenticated || model.isAuthenticating)
			} else {
				Menu {
					Button("Edit", systemImage: "pencil") {
						if model.isAuthenticated { model.isEditing = true }
						else { requestUnlock() }
					}
					if model.isAuthenticated, onArchive != nil {
						Button("Archive", systemImage: "archivebox") {
							showArchiveConfirmation = true
						}
					}
					if model.isAuthenticated, onDelete != nil {
						Divider()
						Button("Delete", systemImage: "trash", role: .destructive) {
							showDeleteConfirmation = true
						}
					}
					if canOfferLegacyMigration {
						Divider()
						Button("Move to encrypted document", systemImage: "lock.doc") {
							showMigrationKindChooser = true
						}
						.disabled(isMigratingLegacyImage)
					}
				} label: {
					Label("Card actions", systemImage: "ellipsis.circle")
				}
			}
		}
	}

	private var macOSEditor: some View {
		VStack(alignment: .leading, spacing: 16) {
			VStack(spacing: 0) {
				macOSFormRow("Card label", text: $model.card.description)
				Divider()
				macOSFormRow("Cardholder", text: $model.card.name)
				Divider()
				macOSFormRow("Card number", text: $model.card.number)
				Divider()
				macOSFormRow("Expiration", text: $model.card.expiration)
				Divider()
				macOSFormRow("Security code", text: $model.card.cvv, isSecure: true)
			}
			.holderSurface(colorScheme)
			.privacySensitive()

			cardPalettePicker
		}
	}

	private var macOSUnlockNotice: some View {
		HStack(spacing: 12) {
			Image(systemName: "lock.fill")
				.foregroundStyle(HolderTheme.mintInk)
				.frame(width: 28, height: 28)
				.background(HolderTheme.mint, in: Circle())
			VStack(alignment: .leading, spacing: 3) {
				Text("Details are masked")
					.font(.headline)
				Text("Unlock with Touch ID or your device passcode to reveal fields temporarily.")
					.font(.footnote)
					.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
			}
			Spacer()
			Button("Unlock", action: requestUnlock)
				.buttonStyle(.borderedProminent)
				.tint(HolderTheme.brandRaised)
		}
		.padding(14)
		.holderSurface(colorScheme)
	}

	private func macOSInfoSection(title: String, value: String) -> some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title.uppercased())
				.font(.caption.weight(.semibold))
				.tracking(0.7)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
			Text(value)
				.foregroundStyle(HolderTheme.primaryText(for: colorScheme))
		}
		.padding(16)
		.frame(maxWidth: .infinity, alignment: .leading)
		.holderSurface(colorScheme)
	}

	private func macOSFormRow(_ label: String, text: Binding<String>, isSecure: Bool = false) -> some View {
		HStack {
			Text(label)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
			Spacer()
			if isSecure {
				SecureField(label, text: text)
					.multilineTextAlignment(.trailing)
			} else {
				TextField(label, text: text)
					.multilineTextAlignment(.trailing)
			}
		}
		.padding(14)
		.frame(minHeight: 52)
	}
	#endif
}

#if os(iOS)
private struct CardScannerRequest: Identifiable {
	let id = UUID()
	let authenticationGeneration: UInt64
}
#endif
