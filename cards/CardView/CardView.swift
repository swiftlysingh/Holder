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

struct CardView: View {

	@StateObject private var model: CardViewModel
	@Environment(\.scenePhase) private var scenePhase
	@AppStorage("isAuthEnabled") private var isAuthEnabled = true
	@AppStorage("timeout") private var authTimeout = 10
	@Environment(\.analytics) private var analytics
	#if os(iOS)
	@Binding private var cardSheetDetent: PresentationDetent
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
		.onAppear {
			model.authenticateUser()
		}
		.onChange(of: scenePhase) {
			#if os(macOS)
			let shouldScheduleLock = scenePhase == .inactive || scenePhase == .background
			#else
			let shouldScheduleLock = scenePhase == .background
			#endif

			if scenePhase == .active {
				model.resolveScheduledLockOnActive()
				// onChange does not fire for the initial phase, so onAppear owns the first prompt.
				if isAuthEnabled
					&& !model.isAuthenticated
					&& !model.isAuthenticating {
					model.authenticateUser()
				}
			} else if shouldScheduleLock && isAuthEnabled && !model.isAuthenticating {
				model.scheduleLock(after: .seconds(authTimeout))
			}
		}
		.onChange(of: isAuthEnabled) { _, isEnabled in
			if isEnabled {
				model.lock()
				if scenePhase == .active {
					model.authenticateUser()
				}
			} else {
				model.authenticateUser()
			}
		}
		.onDisappear {
			model.lock()
		}
		.sdkScreen(
			model.isAddNewFlow
				? AppAnalyticsScreen.cardEditor
				: AppAnalyticsScreen.cardDetails
		)
	}

	#if os(iOS)
	@ViewBuilder
	private func iOSCardContent() -> some View {
		Group {
			if model.isAuthenticated && model.isShowingScanner {
				CardScannerView(
					isRescan: model.didUseScanner,
					onCancel: {
						model.isShowingScanner = false
						cardSheetDetent = model.entryMode == .chooser ? .fraction(0.25) : .large
					},
					onPermissionDenied: {
						track(.cardScanPermissionDenied(engine: CardScanningEngineFactory.currentEngineID))
						model.isShowingScanner = false
						cardSheetDetent = model.entryMode == .chooser ? .fraction(0.25) : .large
					},
					onResult: { result, metrics in
						model.applyScan(result)
						cardSheetDetent = .large
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
			} else if model.entryMode == .chooser {
				scanChooserView()
					.disabled(!model.isAuthenticated)
			} else {
				getCardListView()
			}
		}
		.toolbar(model.isShowingScanner || model.entryMode == .chooser ? .hidden : .automatic, for: .navigationBar)
	}

	private func scanChooserView() -> some View {
		VStack(spacing: 12) {
			HStack(spacing: 12) {
				Image(systemName: "camera.viewfinder")
					.font(.title2)
					.foregroundStyle(Color.accentColor)
				VStack(alignment: .leading, spacing: 2) {
					Text("Add a card")
						.font(.headline)
					Text("Scan the front, then review every field.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				Spacer()
			}
			Button {
				startScan(isRescan: false)
			} label: {
				Text("Scan Card")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)
			Button("Enter Manually") {
				model.beginManualEntry()
				cardSheetDetent = .large
			}
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 16)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
	}

	private func startScan(isRescan: Bool) {
		if isRescan {
			track(.cardScanRescanRequested(engine: CardScanningEngineFactory.currentEngineID))
		}
		track(.cardScanStarted(engine: CardScanningEngineFactory.currentEngineID))
		cardSheetDetent = .fraction(0.5)
		model.isShowingScanner = true
	}

	private func scanReviewSection() -> some View {
		Group {
			if model.isAuthenticated, let preview = model.lastScanPreview {
				Section {
					HStack(spacing: 12) {
						Image(preview.network.rawValue)
							.resizable()
							.scaledToFit()
							.frame(width: 36, height: 36)
						VStack(alignment: .leading, spacing: 4) {
							Text(preview.network.rawValue)
								.font(.headline)
							Text("•••• \(preview.lastFour)")
								.font(.body.monospaced())
							if let expiry = preview.expiry, !expiry.isEmpty {
								Text("Expires \(expiry)")
									.foregroundStyle(.secondary)
							}
							if let name = preview.cardholderName, !name.isEmpty {
								Text(name)
									.foregroundStyle(.secondary)
							}
						}
						Spacer()
					}
					Button {
						startScan(isRescan: true)
					} label: {
						Label("Scan Again", systemImage: "camera.on.rectangle")
					}
				} header: {
					Text("Scanned card")
				} footer: {
					Text("Every field below stays editable. Missing scan values will not erase what you already entered.")
				}
			}
		}
	}
	#endif

	#if os(iOS)
	fileprivate func itemView(heading: String, value: Binding<String>, _ type: UIKeyboardType) -> some View {
		return HStack {
			Text(heading)
				.bold()
			Spacer()
			if !model.isAuthenticated {
				SecureField("", text: value)
					.multilineTextAlignment(.trailing)
			} else {
				TextField("", text: value)
					.multilineTextAlignment(.trailing)
					.disabled(!model.isEditing)
					.foregroundColor(model.isEditing ? .blue : .accentColor)
					.keyboardType(type)
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
		.if(!model.isEditing, transform: { view in
			view.onTapGesture(count: 2, perform: {
				model.copyAction(with: value.wrappedValue)
			})
		})
	}
	#else
	fileprivate func itemView(heading: String, value: Binding<String>) -> some View {
		return HStack {
			Text(heading)
				.bold()
			Spacer()
			if !model.isAuthenticated {
				SecureField("", text: value)
					.multilineTextAlignment(.trailing)
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
		.if(!model.isEditing, transform: { view in
			view.onTapGesture(count: 2, perform: {
				model.copyAction(with: value.wrappedValue)
			})
		})
	}
	#endif

	fileprivate func getCardListView() -> some View {
		let tip = DoubleTapTip()

		return List {
			#if os(iOS)
			scanReviewSection()
			#endif
			Section {
				#if os(iOS)
				let fields: [(String, Binding<String>, UIKeyboardType)] = [
					("Name", $model.card.name, .alphabet),
					("Number", $model.card.number, .numbersAndPunctuation),
					("Expiration", $model.card.expiration, .numberPad),
					("Security Code", $model.card.cvv, .numberPad),
					("Description", $model.card.description, .alphabet)
				]

				ForEach(fields, id: \.0) { heading, value, keyboardType in
					if !value.wrappedValue.isEmpty || model.isEditing {
						let view = itemView(heading: heading, value: value, keyboardType)

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
				let fields: [(String, Binding<String>)] = [
					("Name", $model.card.name),
					("Number", $model.card.number),
					("Expiration", $model.card.expiration),
					("Security Code", $model.card.cvv),
					("Description", $model.card.description)
				]

				ForEach(fields, id: \.0) { heading, value in
					if !value.wrappedValue.isEmpty || model.isEditing {
						let view = itemView(heading: heading, value: value)

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
				  if model.card.type != .otherCard {
					Picker("Card Network", selection: $model.card.network) {
					  ForEach(CardNetwork.allCases) { pref in
						Text(pref.rawValue)
					  }
					}

					.disabled(!model.isEditing)
					.bold()
				  }
					Picker("Card Type", selection: $model.card.type) {
						ForEach(CardType.allCases) { pref in
							Text(pref.rawValue)
						}
					}
					.disabled(!model.isEditing)
					.bold()
				}
			}

			if let image = model.cardImage, model.card.type == .otherCard {
				Section {
					#if os(iOS)
					Image(uiImage: image)
						.resizable()
						.scaledToFit()
						.if(!model.isAuthenticated, transform: { view in
							view.blur(radius: 10, opaque: true)
						})
					#else
					Image(nsImage: image)
						.resizable()
						.scaledToFit()
						.if(!model.isAuthenticated, transform: { view in
							view.blur(radius: 10, opaque: true)
						})
					#endif
				}
			}

			#if os(iOS)
			if model.isEditing && model.card.type == .otherCard {
				Section {
					PhotosPicker(selection: $model.selectedItem, matching: .images) {
						VStack(alignment: .leading) {
							HStack {
								Image(systemName: "photo")
								Text(model.cardImage == nil ? "Add Card Image" : "Change Card Image")
							}
							.padding(.bottom)

							Text("Images are stored in iCloud storage instead of more secure Keychain, please be mindful while adding sensitive images")
								.font(.footnote)
								.foregroundStyle(.gray)
						}
					}
				.onChange(of: model.selectedItem) {
					Task {
						do {
							guard let data = try await model.selectedItem?.loadTransferable(type: Data.self) else {
								throw URLError(.cannotDecodeContentData)
							}

							guard let uiImage = UIImage(data: data) else {
								throw URLError(.cannotDecodeContentData)
							}

							guard ICloudDataManager.shared.saveImage(uiImage, for: model.card.id) else {
								throw URLError(.cannotCreateFile)
							}

							model.cardImage = uiImage
							model.errorMessage = nil
						} catch {
							model.errorMessage = "Unable to save image: \(error.localizedDescription)"
							model.showErrorAlert = true
						}
					}
				}


					if model.cardImage != nil {
						Button(role: .destructive) {
							model.cardImage = nil
							ICloudDataManager.shared.deleteImage(for: model.card.id)
						} label: {
							HStack {
								Image(systemName: "trash")
								Text("Remove Image")
							}
						}
					}
				}
			}
			#else
			if model.isEditing && model.card.type == .otherCard {
				Section {
					Button {
						selectImageFile()
					} label: {
						VStack(alignment: .leading) {
							HStack {
								Image(systemName: "photo")
								Text(model.cardImage == nil ? "Add Card Image" : "Change Card Image")
							}
							.padding(.bottom)

							Text("Images are stored in iCloud storage instead of more secure Keychain, please be mindful while adding sensitive images")
								.font(.footnote)
								.foregroundStyle(.gray)
						}
					}
					.buttonStyle(.plain)

					if model.cardImage != nil {
						Button(role: .destructive) {
							model.cardImage = nil
							ICloudDataManager.shared.deleteImage(for: model.card.id)
						} label: {
							HStack {
								Image(systemName: "trash")
								Text("Remove Image")
							}
						}
					}
				}
			}
			#endif
		}
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
		.toolbar {
			ShareLink(item: model.card.toShareString()) {
				Label("Click to share", systemImage: "square.and.arrow.up")
			}
			Button(action: {
				model.isEditing.toggle()
				saveCardIfNeeded()
			}) {
				Text(model.isEditing ? "Done" : "Edit")
			}
		}
		.disabled(!$model.isAuthenticated.wrappedValue)
		#if os(iOS)
		.toolbar {
			if model.isAddNewFlow && model.card.type != .otherCard && model.entryMode == .form {
				ToolbarItem(placement: .topBarLeading) {
					Button {
						startScan(isRescan: model.didUseScanner)
					} label: {
						Label(
							model.didUseScanner ? "Scan Again" : "Scan Card",
							systemImage: "camera.on.rectangle"
						)
					}
				}
			}
		}
		#endif
	}

	private func saveCardIfNeeded() {
		guard !model.isEditing,
			  model.card.type == .otherCard || !model.card.number.isEmpty else {
			return
		}

		let operation: AppAnalyticsEvent.SaveOperation = model.isAddNewFlow ? .create : .update
		let inputMethod: AppAnalyticsEvent.InputMethod = model.didUseScanner ? .scanner : .manual
		let succeeded = model.addUpdateCard(model.card)
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

	private func track(_ event: AppAnalyticsEvent) {
		Task {
			await analytics.capture(event)
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
			if let image = NSImage(contentsOf: url) {
				if ICloudDataManager.shared.saveImage(image, for: model.card.id) {
					model.cardImage = image
				} else {
					model.errorMessage = "Failed to save image to iCloud"
					model.showErrorAlert = true
				}
			}
		}
	}

	// MARK: - macOS Card View
	@ViewBuilder
	private func macOSCardView() -> some View {
		ScrollView {
			VStack(spacing: 24) {
				// Visual Card Preview (only for credit/debit cards)
				if model.card.type != .otherCard && model.isAuthenticated && !model.isEditing {
					macOSCardPreview()
				}

				// Card Image for Other Cards
				if let image = model.cardImage, model.card.type == .otherCard {
					Image(nsImage: image)
						.resizable()
						.scaledToFit()
						.frame(maxHeight: 300)
						.clipShape(RoundedRectangle(cornerRadius: 12))
						.if(!model.isAuthenticated, transform: { view in
							view.blur(radius: 10, opaque: true)
						})
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
		.contentMargins(0)
		.toolbar {
			ShareLink(item: model.card.toShareString()) {
				Label("Share", systemImage: "square.and.arrow.up")
			}
			Button(action: {
				model.isEditing.toggle()
				saveCardIfNeeded()
			}) {
				Text(model.isEditing ? "Done" : "Edit")
			}
		}
		.disabled(!model.isAuthenticated)
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
					Text(model.card.type.rawValue)
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
							Text("•••")
								.font(.system(size: 13, weight: .medium, design: .monospaced))
								.foregroundStyle(.white)
						}
						.onTapGesture {
							copyToClipboard(model.card.cvv, field: "cvv")
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
					macOSFormRow(label: "CVV", value: $model.card.cvv, isEditing: true)
					Divider()
					macOSFormRow(label: "Description", value: $model.card.description, isEditing: true)
				} else {
					// View mode - show non-empty fields with copy on click
					if !model.card.name.isEmpty {
						macOSCopyableRow(label: "Name", value: model.card.name, field: "name")
						Divider()
					}
					if !model.card.number.isEmpty {
						macOSCopyableRow(label: "Number", value: model.isAuthenticated ? model.card.number : "••••••••••••••••", field: "number")
						Divider()
					}
					if !model.card.expiration.isEmpty {
						macOSCopyableRow(label: "Expiration", value: model.isAuthenticated ? model.card.expiration : "••/••", field: "exp")
						Divider()
					}
					if !model.card.cvv.isEmpty {
						macOSCopyableRow(label: "CVV", value: model.isAuthenticated ? model.card.cvv : "•••", field: "cvv")
						Divider()
					}
					if !model.card.description.isEmpty {
						macOSCopyableRow(label: "Description", value: model.card.description, field: "desc")
					}
				}

				// Pickers
				if model.card.type != .otherCard {
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
					Picker("", selection: $model.card.type) {
						ForEach(CardType.allCases) { type in
							Text(type.rawValue).tag(type)
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
		if model.isEditing && model.card.type == .otherCard {
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

					if model.cardImage != nil {
						Button(role: .destructive) {
							model.cardImage = nil
							ICloudDataManager.shared.deleteImage(for: model.card.id)
						} label: {
							HStack {
								Image(systemName: "trash")
								Text("Remove Image")
							}
						}
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
	private func macOSCopyableRow(label: String, value: String, field: String) -> some View {
		Button {
			if model.isAuthenticated {
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
