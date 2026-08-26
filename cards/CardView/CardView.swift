//
//  CardView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import SinghDevKit
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import PhotosUI
#elseif os(macOS)
import AppKit
#endif

@MainActor
struct CardView: View {

	@StateObject private var model: CardViewModel
	@EnvironmentObject private var authenticationSession: AuthenticationSession
	@Environment(\.analytics) private var analytics
	#if os(iOS)
	@Environment(\.dismiss) private var dismiss
	@Binding private var cardSheetDetent: PresentationDetent
	@State private var isShowingCardForm = false
	@FocusState private var isFieldFocused: Bool
	#endif
	#if os(macOS)
	@State private var copiedField: String?
	#endif

	#if os(iOS)
	init(
		model: CardViewModel,
		cardSheetDetent: Binding<PresentationDetent> = .constant(.large)
	) {
		_model = StateObject(wrappedValue: model)
		_cardSheetDetent = cardSheetDetent
	}
	#else
	init(model: CardViewModel) {
		_model = StateObject(wrappedValue: model)
	}
	#endif

	private var isCVVLocked: Bool {
		!model.isAddNewFlow
			&& !authenticationSession.isSensitiveAccessFresh
	}

	/// Formats expiration date input (auto-inserts "/" after 2 digits, limits to 5 chars)
	private func formatExpirationIfNeeded(_ newValue: String) {
		Task { @MainActor in
			if newValue.count == 2 && !newValue.contains("/") {
				model.card.expiration = newValue + "/"
			} else if newValue.count > 5 {
				model.card.expiration = String(newValue.prefix(5))
			}
		}
	}

	var body: some View {
		Group {
			#if os(macOS)
			macOSCardView()
			#elseif os(iOS)
			iOSCardContent()
			#else
			getCardListView()
			#endif
		}
		.sdkScreen(
			model.isAddNewFlow
				? AppAnalyticsScreen.cardEditor
				: AppAnalyticsScreen.cardDetails
		)
		.disabled(model.isSaving)
	}

	#if os(iOS)
	@ViewBuilder
	private func iOSCardContent() -> some View {
		VStack(spacing: 0) {
			if model.isAddNewFlow && isShowingCardForm && !model.isShowingScanner {
				addCardHeader
			}

			if authenticationSession.isVaultUnlocked && model.isShowingScanner {
				CardScannerView(
					isRescan: model.didUseScanner,
					onCancel: {
						dismiss()
					},
					onPermissionDenied: {
						track(.cardScanPermissionDenied(engine: CardScanningEngineFactory.currentEngineID))
						showCardForm()
					},
					onManualEntry: {
						showCardForm()
					},
					onResult: { result, metrics in
						model.applyScan(result)
						showCardForm()
						track(
							.cardScanCompleted(
								engine: metrics.engine,
								panSuccess: metrics.panSuccess,
								expirySuccess: metrics.expirySuccess,
								holderSuccess: metrics.holderSuccess,
								timeToPanMs: metrics.timeToPANMs,
								timeToCompleteMs: metrics.timeToCompleteMs,
								rescan: metrics.wasRescan
							)
						)
					}
				)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.clipped()
			}

			if !model.isAddNewFlow || isShowingCardForm {
				getCardListView()
					.disabled(model.isShowingScanner)
			}
		}
		.ignoresSafeArea(
			.container,
			edges: model.isShowingScanner ? .all : []
		)
		.safeAreaInset(edge: .bottom, spacing: 0) {
			if model.isAddNewFlow && isShowingCardForm && !model.isShowingScanner {
				addCardActionButton
			}
		}
		.onAppear {
			guard model.isAddNewFlow, !isShowingCardForm, !model.isShowingScanner else { return }
			if model.startMode == .manual {
				showCardForm()
			} else {
				startScan()
			}
		}
		.onChange(of: authenticationSession.isVaultUnlocked) { _, isUnlocked in
			if !isUnlocked && model.isShowingScanner {
				dismiss()
			}
		}
		.onDisappear {
			model.isShowingScanner = false
		}
	}

	private var addCardHeader: some View {
		Text("Add a Card")
			.font(.title2.weight(.semibold))
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, 20)
			.padding(.top, 24)
			.padding(.bottom, 16)
			.accessibilityAddTraits(.isHeader)
	}

	private var addCardActionButton: some View {
		Button {
			Task { @MainActor in
				await saveCardIfNeeded()
			}
		} label: {
			Group {
				if model.isSaving {
					ProgressView()
				} else {
					Text("Add Card")
				}
			}
			.frame(maxWidth: .infinity)
		}
		.buttonStyle(.borderedProminent)
		.controlSize(.large)
		.disabled(!model.canFinishEditing || model.isShowingScanner || model.isSaving)
		.padding(.horizontal, 20)
		.padding(.vertical, 12)
		.background(.bar)
		.accessibilityIdentifier("addCardButton")
		.accessibilityLabel("Add Card")
	}

	private func startScan() {
		track(.cardScanStarted(engine: CardScanningEngineFactory.currentEngineID))
		isFieldFocused = false
		withAnimation {
			cardSheetDetent = .height(430)
			model.isShowingScanner = true
		}
	}

	private func showCardForm() {
		isFieldFocused = false
		withAnimation {
			isShowingCardForm = true
			model.isShowingScanner = false
			cardSheetDetent = .fraction(0.5)
		}
	}
	#endif

	#if os(iOS)
	fileprivate func itemView(
		heading: String,
		value: Binding<String>,
		keyboardType: UIKeyboardType,
		requiresAuthentication: Bool
	) -> some View {
		return HStack {
			Text(heading)
				.bold()
			Spacer()
			if requiresAuthentication && isCVVLocked {
				Button {
					authenticateForCVV()
				} label: {
					Label("Authenticate to view", systemImage: "lock.fill")
						.labelStyle(.titleAndIcon)
				}
				.disabled(authenticationSession.isAuthenticating)
				.accessibilityLabel("Authenticate to view security code")
			} else {
				TextField(heading, text: value)
					.labelsHidden()
					.multilineTextAlignment(.trailing)
					.disabled(!model.isEditing)
					.foregroundColor(model.isEditing ? .blue : .accentColor)
					.keyboardType(keyboardType)
					.focused($isFieldFocused)
					.contextMenu(menuItems: {
						Button(action: {
							model.copyAction(with: value.wrappedValue)
							UserSettings.shared.requestReview()
						}) {
							Text("Copy to clipboard")
							Image(systemName: "doc.on.doc")
						}
					})
			}
		}
		.if(!model.isEditing && (!requiresAuthentication || !isCVVLocked), transform: { view in
			view.onTapGesture(count: 2, perform: {
				model.copyAction(with: value.wrappedValue)
			})
		})
	}
	#else
	fileprivate func itemView(
		heading: String,
		value: Binding<String>,
		requiresAuthentication: Bool
	) -> some View {
		return HStack {
			Text(heading)
				.bold()
			Spacer()
			if requiresAuthentication && isCVVLocked {
				Button("Authenticate to view") {
					authenticateForCVV()
				}
				.disabled(authenticationSession.isAuthenticating)
				.accessibilityLabel("Authenticate to view security code")
			} else {
				TextField("", text: value)
					.multilineTextAlignment(.trailing)
					.disabled(!model.isEditing)
					.foregroundColor(model.isEditing ? .blue : .accentColor)
					.contextMenu(menuItems: {
						Button(action: {
							model.copyAction(with: value.wrappedValue)
							UserSettings.shared.requestReview()
						}) {
							Text("Copy to clipboard")
							Image(systemName: "doc.on.doc")
						}
					})
			}
		}
		.if(!model.isEditing && (!requiresAuthentication || !isCVVLocked), transform: { view in
			view.onTapGesture(count: 2, perform: {
				model.copyAction(with: value.wrappedValue)
			})
		})
	}
	#endif

	fileprivate func getCardListView() -> some View {
		let tip = DoubleTapTip()
		let hasCardImage = model.cardImage != nil

		return List {
			Section {
				#if os(iOS)
				let fields: [(String, Binding<String>, UIKeyboardType, Bool)] = [
					("Name", $model.card.name, .alphabet, false),
					("Number", $model.card.number, .numbersAndPunctuation, false),
					("Expiration", $model.card.expiration, .numberPad, false),
					("Security Code", $model.card.cvv, .numberPad, true),
					("Description", $model.card.description, .alphabet, false)
				]

				ForEach(fields, id: \.0) { heading, value, keyboardType, requiresAuthentication in
					if !value.wrappedValue.isEmpty || model.isEditing {
						let view = itemView(
							heading: heading,
							value: value,
							keyboardType: keyboardType,
							requiresAuthentication: requiresAuthentication
						)

						if heading == "Number" && !model.isEditing {
							view.popoverTip(tip, arrowEdge: .top)
						} else if heading == "Expiration" {
							view.onChange(of: model.card.expiration) { _, newValue in
								formatExpirationIfNeeded(newValue)
							}
						} else {
							view
						}
					}
				}
				#else
				let fields: [(String, Binding<String>, Bool)] = [
					("Name", $model.card.name, false),
					("Number", $model.card.number, false),
					("Expiration", $model.card.expiration, false),
					("Security Code", $model.card.cvv, true),
					("Description", $model.card.description, false)
				]

				ForEach(fields, id: \.0) { heading, value, requiresAuthentication in
					if !value.wrappedValue.isEmpty || model.isEditing {
						let view = itemView(
							heading: heading,
							value: value,
							requiresAuthentication: requiresAuthentication
						)

						if heading == "Number" && !model.isEditing {
							view.popoverTip(tip, arrowEdge: .top)
						} else if heading == "Expiration" {
							view.onChange(of: model.card.expiration) { _, newValue in
								formatExpirationIfNeeded(newValue)
							}
						} else {
							view
						}
					}
				}
				#endif

				Group {
				  if model.selectedCardType != .other {
					Picker("Card Network", selection: $model.card.network) {
					  ForEach(CardNetwork.allCases) { pref in
						Text(pref.rawValue)
					  }
					}

					.disabled(!model.isEditing)
					.bold()
				  }
					Picker("Card Type", selection: $model.selectedCardType) {
						if model.isAddNewFlow {
							Text("Select Card Type").tag(nil as CardType?)
						}
						ForEach(CardType.allCases) { pref in
							Text(pref.rawValue).tag(pref as CardType?)
						}
					}
					.disabled(!model.isEditing)
					.bold()
				}
			}

			if let image = model.cardImage, model.selectedCardType == .other {
				Section {
					#if os(iOS)
					Image(uiImage: image)
						.resizable()
						.scaledToFit()
					#else
					Image(nsImage: image)
						.resizable()
						.scaledToFit()
					#endif
				}
			}

			#if os(iOS)
			if model.isEditing && model.selectedCardType == .other {
				Section {
					PhotosPicker(selection: $model.selectedItem, matching: .images) {
						VStack(alignment: .leading) {
							HStack {
								Image(systemName: "photo")
								Text(hasCardImage ? "Change Card Image" : "Add Card Image")
							}
							.padding(.bottom)

							Text("Images are stored in iCloud storage instead of more secure Keychain, please be mindful while adding sensitive images")
								.font(.footnote)
								.foregroundStyle(.gray)
						}
					}
					.disabled(model.isImageMutationInProgress)
					.onChange(of: model.selectedItem) {
						guard let item = model.selectedItem else { return }
						model.saveStoredImage {
							guard let data = try await item.loadTransferable(type: Data.self) else {
								throw URLError(.cannotDecodeContentData)
							}
							return data
						}
					}

					if model.cardImage != nil {
						Button(role: .destructive) {
							model.removeStoredImage()
						} label: {
							HStack {
								Image(systemName: "trash")
								Text("Remove Image")
							}
						}
						.disabled(model.isImageMutationInProgress)
					}
				}
			}
			#else
			if model.isEditing && model.selectedCardType == .other {
				Section {
					Button {
						selectImageFile()
					} label: {
						VStack(alignment: .leading) {
							HStack {
								Image(systemName: "photo")
								Text(hasCardImage ? "Change Card Image" : "Add Card Image")
							}
							.padding(.bottom)

							Text("Images are stored in iCloud storage instead of more secure Keychain, please be mindful while adding sensitive images")
								.font(.footnote)
								.foregroundStyle(.gray)
						}
					}
					.buttonStyle(.plain)
					.disabled(model.isImageMutationInProgress)

					if model.cardImage != nil {
						Button(role: .destructive) {
							model.removeStoredImage()
						} label: {
							HStack {
								Image(systemName: "trash")
								Text("Remove Image")
							}
						}
						.disabled(model.isImageMutationInProgress)
					}
				}
			}
			#endif
		}
		.scrollContentBackground(.hidden)
		.background(Color.appBackground)
		.alert("Image Error", isPresented: $model.showErrorAlert) {
			Button("OK", role: .cancel) {
				model.showErrorAlert = false
			}
		} message: {
			if let message = model.errorMessage {
				Text(message)
			} else {
				Text("An unknown error occurred")
			}
		}
		.if(model.isAddNewFlow, transform: { view in
			view.contentMargins(.top, 0, for: .scrollContent)
		})
		.toolbar {
			if !model.isAddNewFlow {
				sensitiveShareMenu
				editToolbarButton
			}
		}
	}
	private var editToolbarButton: some View {
		Button(action: toggleEditing) {
			if model.isEditing {
				Text("Done")
			} else {
				Image(systemName: "pencil")
			}
		}
		.accessibilityLabel(model.isEditing ? "Done" : "Edit")
		.disabled(model.isEditing && (!model.canFinishEditing || model.isSaving))
	}

	private func saveCardIfNeeded() async {
		let operation: AppAnalyticsEvent.SaveOperation = model.isAddNewFlow ? .create : .update
		let inputMethod: AppAnalyticsEvent.InputMethod = model.didUseScanner ? .scanner : .manual
		guard let succeeded = await model.saveCard() else { return }
		let event: AppAnalyticsEvent = succeeded
			? .cardSaveCompleted(
				operation: operation,
				inputMethod: inputMethod
			)
			: .cardSaveFailed(
				operation: operation,
				inputMethod: inputMethod
			)
		track(event)
	}

	private func toggleEditing() {
		if model.isEditing {
			Task { @MainActor in
				await saveCardIfNeeded()
			}
		} else {
			model.isEditing = true
		}
	}

	private func track(_ event: AppAnalyticsEvent) {
		Task {
			await analytics.capture(event)
		}
	}

	private func authenticateForCVV() {
		authenticationSession.authenticateForSensitiveAccess(
			reason: "Authenticate to view this card’s security code."
		)
	}

	@ViewBuilder
	private var sensitiveShareMenu: some View {
		if authenticationSession.isSensitiveAccessFresh {
			Menu {
				ShareLink(item: model.card.toShareString(includeSecurityCode: false)) {
					Label("Share without Security Code", systemImage: "square.and.arrow.up")
				}
				if !model.card.cvv.isEmpty {
					ShareLink(item: model.card.toShareString(includeSecurityCode: true)) {
						Label("Share with Security Code", systemImage: "lock.open.fill")
					}
				}
			} label: {
				Label("Share", systemImage: "square.and.arrow.up")
			}
		} else {
			Button {
				authenticationSession.authenticateForSensitiveAccess(
					reason: "Authenticate to share card details."
				)
			} label: {
				Label("Authenticate to Share", systemImage: "lock.open.fill")
			}
			.disabled(authenticationSession.isAuthenticating)
		}
	}

	#if os(macOS)
	private func selectImageFile() {
		let panel = NSOpenPanel()
		panel.allowedContentTypes = [.image]
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.canCreateDirectories = false
		panel.title = "Select Card Image"

		if panel.runModal() == .OK, let url = panel.url {
			model.saveStoredImage {
				try await Task.detached(priority: .userInitiated) {
					try Data(contentsOf: url)
				}.value
			}
		}
	}

	// MARK: - macOS Card View
	@ViewBuilder
	private func macOSCardView() -> some View {
		ScrollView {
			VStack(spacing: 24) {
				// Visual Card Preview (only for credit/debit cards)
				if model.selectedCardType != .other && !model.isEditing {
					macOSCardPreview()
				}

				// Card Image for Other Cards
				if let image = model.cardImage, model.selectedCardType == .other {
					Image(nsImage: image)
						.resizable()
						.scaledToFit()
						.frame(maxHeight: 300)
						.clipShape(RoundedRectangle(cornerRadius: 12))
				}

				// Card Details Form
				macOSCardForm()
			}
			.padding(.top, 24)
			.padding(.bottom, 24)
			.padding(.horizontal, 24)
			.frame(maxWidth: .infinity)
		}
		.scrollContentBackground(.hidden)
		.background(Color.appBackground)
		.contentMargins(0)
		.toolbar {
			sensitiveShareMenu
			editToolbarButton
		}
	}

	@ViewBuilder
	private func macOSCardPreview() -> some View {
		ZStack {
			// Card Background
			RoundedRectangle(cornerRadius: 16)
				.fill(
					LinearGradient(
						colors: [Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.6)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
				.shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

			VStack(alignment: .leading, spacing: 16) {
				// Top row: Network logo and type
				HStack {
					// Show network logo if available, otherwise show icon
					if model.card.network != .other {
						Image(model.card.network.rawValue)
							.renderingMode(.original)
							.resizable()
							.scaledToFit()
							.frame(height: 36)
					} else {
						Image(systemName: "creditcard.fill")
							.font(.system(size: 24))
							.foregroundStyle(.white.opacity(0.9))
					}
					Spacer()
					Text(model.selectedCardType?.rawValue ?? "Card")
						.font(.caption)
						.fontWeight(.medium)
						.foregroundStyle(.white.opacity(0.8))
				}

				Spacer()

				// Card Number
				Text(formatCardNumber(model.card.number))
					.font(.system(size: 20, weight: .medium, design: .monospaced))
					.foregroundStyle(.white)
					.onTapGesture {
						copyToClipboard(model.card.number, field: "number")
					}

				// Bottom row: Name and Expiry
				HStack(alignment: .bottom) {
					VStack(alignment: .leading, spacing: 2) {
						Text("CARDHOLDER")
							.font(.system(size: 9, weight: .medium))
							.foregroundStyle(.white.opacity(0.6))
						Text(model.card.name.isEmpty ? "Your Name" : model.card.name.uppercased())
							.font(.system(size: 13, weight: .medium))
							.foregroundStyle(.white)
							.lineLimit(1)
					}
					.onTapGesture {
						if !model.card.name.isEmpty {
							copyToClipboard(model.card.name, field: "name")
						}
					}

					Spacer()

					if !model.card.expiration.isEmpty {
						VStack(alignment: .trailing, spacing: 2) {
							Text("EXPIRES")
								.font(.system(size: 9, weight: .medium))
								.foregroundStyle(.white.opacity(0.6))
							Text(model.card.expiration)
								.font(.system(size: 13, weight: .medium, design: .monospaced))
								.foregroundStyle(.white)
						}
						.onTapGesture {
							copyToClipboard(model.card.expiration, field: "exp")
						}
					}

					if !model.card.cvv.isEmpty {
						VStack(alignment: .trailing, spacing: 2) {
							Text("CVV")
								.font(.system(size: 9, weight: .medium))
								.foregroundStyle(.white.opacity(0.6))
							Text(isCVVLocked ? "•••" : model.card.cvv)
								.font(.system(size: 13, weight: .medium, design: .monospaced))
								.foregroundStyle(.white)
						}
						.onTapGesture {
							if isCVVLocked {
								authenticateForCVV()
							} else {
								copyToClipboard(model.card.cvv, field: "cvv")
							}
						}
					}
				}
			}
			.padding(20)

			// Copied feedback overlay
			if let field = copiedField {
				VStack {
					HStack {
						Image(systemName: "checkmark.circle.fill")
						Text("Copied \(fieldName(field))!")
					}
					.font(.headline)
					.foregroundStyle(.white)
					.padding(.horizontal, 16)
					.padding(.vertical, 10)
					.background(.black.opacity(0.7))
					.clipShape(Capsule())
				}
			}
		}
		.frame(width: 340, height: 200)
	}

	@ViewBuilder
	private func macOSCardForm() -> some View {
		GroupBox {
			VStack(spacing: 0) {
				if model.isEditing {
					// Editing mode - show all fields
					macOSFormRow(label: "Name", value: $model.card.name, isEditing: true)
					Divider()
					macOSFormRow(label: "Number", value: $model.card.number, isEditing: true)
					Divider()
					macOSFormRow(label: "Expiration", value: $model.card.expiration, isEditing: true)
						.onChange(of: model.card.expiration) { _, newValue in
							formatExpirationIfNeeded(newValue)
						}
					Divider()
					if isCVVLocked {
						macOSCopyableRow(label: "CVV", value: "•••", field: "cvv", requiresAuthentication: true)
					} else {
						macOSFormRow(label: "CVV", value: $model.card.cvv, isEditing: true)
					}
					Divider()
					macOSFormRow(label: "Description", value: $model.card.description, isEditing: true)
				} else {
					// View mode - show non-empty fields with copy on click
					if !model.card.name.isEmpty {
						macOSCopyableRow(label: "Name", value: model.card.name, field: "name")
						Divider()
					}
					if !model.card.number.isEmpty {
						macOSCopyableRow(label: "Number", value: model.card.number, field: "number")
						Divider()
					}
					if !model.card.expiration.isEmpty {
						macOSCopyableRow(label: "Expiration", value: model.card.expiration, field: "exp")
						Divider()
					}
					if !model.card.cvv.isEmpty {
						macOSCopyableRow(
							label: "CVV",
							value: isCVVLocked ? "•••" : model.card.cvv,
							field: "cvv",
							requiresAuthentication: true
						)
						Divider()
					}
					if !model.card.description.isEmpty {
						macOSCopyableRow(label: "Description", value: model.card.description, field: "desc")
					}
				}

				// Pickers
				if model.selectedCardType != .other {
					Divider()
					HStack {
						Text("Network")
							.foregroundStyle(.secondary)
						Spacer()
						Picker("", selection: $model.card.network) {
							ForEach(CardNetwork.allCases) { network in
								Text(network.rawValue).tag(network)
							}
						}
						.labelsHidden()
						.disabled(!model.isEditing)
					}
					.padding(.horizontal, 12)
					.padding(.vertical, 8)
				}

				Divider()
				HStack {
					Text("Type")
						.foregroundStyle(.secondary)
					Spacer()
					Picker("", selection: $model.selectedCardType) {
						if model.isAddNewFlow {
							Text("Select Card Type").tag(nil as CardType?)
						}
						ForEach(CardType.allCases) { type in
							Text(type.rawValue).tag(type as CardType?)
						}
					}
					.labelsHidden()
					.disabled(!model.isEditing)
				}
				.padding(.horizontal, 12)
				.padding(.vertical, 8)
			}
		} label: {
			Text("Card Details")
				.font(.headline)
		}
		.frame(maxWidth: 400)

		// Image section for Other Cards
		if model.isEditing && model.selectedCardType == .other {
			GroupBox {
				VStack(spacing: 12) {
					Button {
						selectImageFile()
					} label: {
						HStack {
							Image(systemName: "photo")
							Text(model.cardImage == nil ? "Add Card Image" : "Change Card Image")
						}
					}
					.disabled(model.isImageMutationInProgress)

					if model.cardImage != nil {
						Button(role: .destructive) {
							model.removeStoredImage()
						} label: {
							HStack {
								Image(systemName: "trash")
								Text("Remove Image")
							}
						}
						.disabled(model.isImageMutationInProgress)
					}

					Text("Images are stored in iCloud storage")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				.padding(.vertical, 4)
			} label: {
				Text("Card Image")
					.font(.headline)
			}
			.frame(maxWidth: 400)
		}
	}

	@ViewBuilder
	private func macOSFormRow(label: String, value: Binding<String>, isEditing: Bool) -> some View {
		HStack {
			Text(label)
				.foregroundStyle(.secondary)
			Spacer()
			TextField("", text: value)
				.textFieldStyle(.plain)
				.multilineTextAlignment(.trailing)
				.disabled(!isEditing)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
	}

	@ViewBuilder
	private func macOSCopyableRow(
		label: String,
		value: String,
		field: String,
		requiresAuthentication: Bool = false
	) -> some View {
		Button {
			if requiresAuthentication && isCVVLocked {
				authenticateForCVV()
			} else {
				copyToClipboard(getActualValue(for: field), field: field)
			}
		} label: {
			HStack {
				Text(label)
					.foregroundStyle(.secondary)
				Spacer()
				if copiedField == field {
					HStack(spacing: 4) {
						Image(systemName: "checkmark")
							.foregroundStyle(.green)
						Text("Copied!")
							.foregroundStyle(.green)
					}
				} else {
					Text(value)
						.foregroundStyle(.primary)
				}
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}

	private func getActualValue(for field: String) -> String {
		switch field {
		case "name": return model.card.name
		case "number": return model.card.number
		case "exp": return model.card.expiration
		case "cvv": return model.card.cvv
		case "desc": return model.card.description
		default: return ""
		}
	}

	private func formatCardNumber(_ number: String) -> String {
		let clean = number.replacingOccurrences(of: " ", with: "")
		var result = ""
		for (index, char) in clean.enumerated() {
			if index > 0 && index % 4 == 0 {
				result += " "
			}
			result.append(char)
		}
		return result.isEmpty ? "•••• •••• •••• ••••" : result
	}

	private func fieldName(_ field: String) -> String {
		switch field {
		case "number": return "number"
		case "name": return "name"
		case "exp": return "expiry"
		case "cvv": return "CVV"
		case "desc": return "description"
		default: return field
		}
	}

	private func copyToClipboard(_ value: String, field: String) {
		PasteboardService.copy(value)
		copiedField = field
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
			if copiedField == field {
				copiedField = nil
			}
		}
	}
	#endif
}
