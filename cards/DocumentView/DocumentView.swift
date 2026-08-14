//
//  DocumentView.swift
//  Holder
//
//  Documents are a separate, photo-first surface with encrypted local
//  attachments. Legacy Other Cards enter this model only through the explicit,
//  verified migration flow.
//

import SinghDevKit
import SwiftUI

#if os(macOS)
import AppKit
#else
import PhotosUI
import UIKit
#endif

final class DocumentViewModel: ObservableObject {
	@Published var document: DocumentData
	@Published var isEditing: Bool
	@Published private(set) var isAuthenticated = false
	@Published private(set) var isAuthenticating = false
	@Published private(set) var frontImage: PlatformImage?
	@Published private(set) var backImage: PlatformImage?
	@Published private(set) var copiedFieldID: UUID?
	@Published var errorMessage: String?
	@Published var showsError = false

	#if !os(macOS)
	@Published var selectedFrontPhoto: PhotosPickerItem?
	@Published var selectedBackPhoto: PhotosPickerItem?
	#endif

	let isNewDocument: Bool
	private let documentStore: DocumentDataStore
	private let authenticatorFactory: CardAuthenticatorFactory
	private var activeAuthenticator: CardAuthenticating?
	private var authenticationAttemptID: UInt64 = 0
	private var copiedTask: Task<Void, Never>?
	/// Newly picked photos remain only in memory until a new document is saved.
	/// This makes Cancel a true no-write operation for the add-document flow.
	private var stagedAttachments: [DocumentAttachmentSide: Data] = [:]
	/// Set only after the person presses Done and metadata has reached the
	/// Keychain. A failed later attachment write can then be retried without
	/// resetting a successfully encrypted earlier side to `false`.
	private var hasPersistedNewMetadata = false
	/// Once a discard has partially run, retrying Save could recreate metadata
	/// for attachment bytes whose encryption key was already erased. Cleanup is
	/// therefore the only safe next action until deletion succeeds.
	private var requiresDiscardRetry = false
	/// Captured before asynchronous photo transfer. Relock or a new authentication
	/// attempt changes this value and invalidates stale picker completions.
	var authenticationGeneration: UInt64 { authenticationAttemptID }

	init(
		document: DocumentData,
		documentStore: DocumentDataStore,
		isEditing: Bool = false,
		isNewDocument: Bool = false,
		authenticatorFactory: CardAuthenticatorFactory = DefaultCardAuthenticatorFactory()
	) {
		self.document = document
		self.documentStore = documentStore
		self.isEditing = isEditing
		self.isNewDocument = isNewDocument
		self.authenticatorFactory = authenticatorFactory
	}

	deinit {
		copiedTask?.cancel()
		activeAuthenticator?.invalidate()
	}

	/// Documents intentionally ignore the global card-auth setting. Every open
	/// requires a fresh device-owner evaluation and starts without photo bytes.
	func unlock() {
		guard !isAuthenticating else { return }
		invalidateAuthenticationAttempt()

		let authenticator = authenticatorFactory.makeAuthenticator()
		activeAuthenticator = authenticator
		let attemptID = authenticationAttemptID
		guard authenticator.canEvaluateDeviceOwnerAuthentication() else {
			authenticator.invalidate()
			activeAuthenticator = nil
			errorMessage = "Device-owner authentication is not available on this device."
			showsError = true
			return
		}

		isAuthenticating = true
		authenticator.evaluateDeviceOwnerAuthentication(
			reason: "Authenticate to open this document in Holder."
		) { [weak self] success in
			Task { @MainActor in
				guard let self, attemptID == self.authenticationAttemptID else { return }
				self.activeAuthenticator = nil
				self.isAuthenticating = false
				guard success else { return }
				self.isAuthenticated = true
				self.loadAttachments()
			}
		}
	}

	func lock() {
		invalidateAuthenticationAttempt()
		isAuthenticated = false
		frontImage = nil
		backImage = nil
		discardStagedPlaintextAttachments()
		copiedFieldID = nil
		copiedTask?.cancel()
		copiedTask = nil
		#if !os(macOS)
		selectedFrontPhoto = nil
		selectedBackPhoto = nil
		#endif
	}

	func persist() -> Bool {
		guard isAuthenticated else { return false }
		guard !requiresDiscardRetry else {
			showError("Finish cancelling this incomplete document before saving again.")
			return false
		}
		document.title = document.title.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !document.title.isEmpty else {
			showError("Give the document a title before saving.")
			return false
		}

		document.fields.removeAll {
			$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
				&& ($0.label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
		}

		do {
			if isNewDocument {
				try persistNewDocument()
			} else {
				try documentStore.update(document)
			}
			return true
		} catch {
			showError("Holder could not save this document. Try again.")
			return false
		}
	}

	func saveAttachment(
		_ data: Data,
		side: DocumentAttachmentSide,
		authenticationGeneration: UInt64
	) {
		guard isAuthenticated, authenticationGeneration == authenticationAttemptID else { return }
		guard let image = PlatformImage(data: data) else {
			showError("Holder could not read that photo.")
			return
		}

		if isNewDocument {
			stagedAttachments[side] = data
			document.setHasImage(true, for: side)
			setImage(image, for: side)
			return
		}

		do {
			let persisted = try documentStore.saveAttachment(data, for: document, side: side)
			applyPersistedAttachmentState(from: persisted)
			setImage(image, for: side)
		} catch {
			showError("Holder could not encrypt and save this photo. Try again.")
		}
	}

	func removeAttachment(_ side: DocumentAttachmentSide) {
		guard isAuthenticated else { return }
		if isNewDocument {
			if stagedAttachments.removeValue(forKey: side) != nil {
				document.setHasImage(false, for: side)
				setImage(nil, for: side)
				return
			}
			if hasPersistedNewMetadata, document.hasImage(for: side) {
				do {
					let persisted = try documentStore.deleteAttachment(for: document, side: side)
					applyPersistedAttachmentState(from: persisted)
					setImage(nil, for: side)
				} catch {
					showError("Holder could not remove this photo. Try again.")
				}
				return
			}
			document.setHasImage(false, for: side)
			setImage(nil, for: side)
			return
		}

		do {
			let persisted = try documentStore.deleteAttachment(for: document, side: side)
			applyPersistedAttachmentState(from: persisted)
			setImage(nil, for: side)
		} catch {
			showError("Holder could not remove this photo. Try again.")
		}
	}

	func copy(_ field: DocumentField) {
		guard isAuthenticated, !field.value.isEmpty else { return }
		PasteboardService.copy(field.value)
		HapticService.trigger(.light)
		copiedTask?.cancel()
		copiedFieldID = field.id
		copiedTask = Task { @MainActor [weak self] in
			do {
				try await Task.sleep(for: .seconds(2))
			} catch {
				return
			}
			guard let self, !Task.isCancelled else { return }
			self.copiedFieldID = nil
		}
	}

	func addField() {
		document.fields.append(DocumentField(kind: .documentNumber, value: ""))
	}

	func removeField(id: UUID) {
		document.fields.removeAll { $0.id == id }
	}

	/// Cancelling the add flow leaves no metadata, encrypted file, or document
	/// key behind. This is also used after a failed first save so a person can
	/// choose Cancel instead of retrying an incomplete new document.
	func discardNewDocument() -> Bool {
		guard isNewDocument else { return true }
		if hasPersistedNewMetadata {
			do {
				try documentStore.delete(document)
				hasPersistedNewMetadata = false
				requiresDiscardRetry = false
			} catch {
				// Preserve the staged editor state. The person can retry Cancel without
				// losing the photos that identify the incomplete saved record.
				requiresDiscardRetry = true
				showError("Holder could not discard the incomplete document. Retry Cancel to finish secure cleanup.")
				return false
			}
		}

		stagedAttachments.removeAll()
		lock()
		return true
	}

	private func persistNewDocument() throws {
		// Write metadata with no attachment claims first. Each attachment write then
		// atomically marks its own slot present, so a failed encryption operation
		// cannot leave metadata saying a photo exists when it does not.
		if !hasPersistedNewMetadata {
			var metadata = document
			for side in DocumentAttachmentSide.allCases {
				metadata.setHasImage(false, for: side)
			}
			try documentStore.add(metadata)
			document = metadata
			hasPersistedNewMetadata = true
		} else {
			try documentStore.update(document)
		}

		var persisted = document

		for side in DocumentAttachmentSide.allCases {
			guard let data = stagedAttachments[side] else { continue }
			persisted = try documentStore.saveAttachment(data, for: persisted, side: side)
			stagedAttachments.removeValue(forKey: side)
			document = persisted
		}
		document = persisted
	}

	private func loadAttachments() {
		for side in DocumentAttachmentSide.allCases {
			do {
				let data = try documentStore.attachmentData(for: document.id, side: side)
					?? stagedAttachments[side]
				setImage(data.flatMap { PlatformImage(data: $0) }, for: side)
			} catch {
				// Preserve the metadata state, but never leave stale photo bytes on
				// screen after a failed decrypt/read.
				setImage(nil, for: side)
				showError("Holder could not open one of this document’s photos.")
			}
		}
	}

	private func setImage(_ image: PlatformImage?, for side: DocumentAttachmentSide) {
		switch side {
		case .front:
			frontImage = image
		case .back:
			backImage = image
		}
	}

	/// Attachment writes use the store's current metadata record. Merge only the
	/// authoritative photo-presence flags back into the in-progress editor so a
	/// person does not lose title or field edits made before tapping Done.
	private func applyPersistedAttachmentState(from persisted: DocumentData) {
		for side in DocumentAttachmentSide.allCases {
			document.setHasImage(persisted.hasImage(for: side), for: side)
		}
	}

	private func discardStagedPlaintextAttachments() {
		for side in stagedAttachments.keys {
			let persistedState = hasPersistedNewMetadata
				? documentStore.document(with: document.id)?.hasImage(for: side) ?? false
				: false
			document.setHasImage(persistedState, for: side)
		}
		stagedAttachments.removeAll()
	}

	private func invalidateAuthenticationAttempt() {
		authenticationAttemptID &+= 1
		activeAuthenticator?.invalidate()
		activeAuthenticator = nil
		isAuthenticating = false
	}

	private func showError(_ message: String) {
		errorMessage = message
		showsError = true
	}
}

struct DocumentView: View {
	@StateObject private var model: DocumentViewModel
	private let onArchive: ((DocumentData) -> Bool)?
	private let onDelete: ((DocumentData) -> Bool)?

	@Environment(\.dismiss) private var dismiss
	@Environment(\.analytics) private var analytics
	@Environment(\.scenePhase) private var scenePhase
	@Environment(\.colorScheme) private var colorScheme
	@State private var showArchiveConfirmation = false
	@State private var showDeleteConfirmation = false
	#if os(iOS) && canImport(VisionKit)
	/// A scan captures both its destination and the authentication attempt that
	/// opened it. Relocking while the scanner is presented invalidates this
	/// request before any scanned bytes can reach the document store.
	@State private var scannerRequest: DocumentScanRequest?
	#endif

	init(
		model: DocumentViewModel,
		onArchive: ((DocumentData) -> Bool)? = nil,
		onDelete: ((DocumentData) -> Bool)? = nil
	) {
		_model = StateObject(wrappedValue: model)
		self.onArchive = onArchive
		self.onDelete = onDelete
	}

	var body: some View {
		Group {
			#if os(macOS)
			macOSDocumentView
			#else
			iosDocumentView
			#endif
		}
		.background(HolderTheme.background(for: colorScheme).ignoresSafeArea())
		.onAppear {
			// A reused view may have been retained by a split view; it must never
			// inherit an earlier document's authenticated state.
			model.lock()
		}
		.onChange(of: scenePhase) { _, phase in
			if phase == .background || (phase == .inactive && !model.isAuthenticating) {
				model.lock()
			}
		}
		.onDisappear {
			model.lock()
		}
		.alert("Archive this document?", isPresented: $showArchiveConfirmation) {
			Button("Archive", role: .destructive, action: archiveDocument)
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("You can restore it from Archived.")
		}
		.alert("Delete this document?", isPresented: $showDeleteConfirmation) {
			Button("Delete", role: .destructive, action: deleteDocument)
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("This removes encrypted photos, their encryption key, and document metadata from this device.")
		}
		.alert("Document error", isPresented: $model.showsError) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(model.errorMessage ?? "Holder could not complete that action.")
		}
		.sdkScreen(model.isEditing ? AppAnalyticsScreen.documentEditor : AppAnalyticsScreen.documentDetails)
		#if os(iOS) && canImport(VisionKit)
		.sheet(item: $scannerRequest) { request in
			DocumentScannerView(
				onScan: { data in
					completeDocumentScan(data, for: request)
				},
				onCancel: {
					scannerRequest = nil
				},
				onFailure: {
					handleDocumentScanFailure(for: request)
				}
			)
			.ignoresSafeArea()
		}
		#endif
	}

	/// A fixed, five-slot palette control. `nil` retains the document's automatic
	/// visual treatment until a person chooses one of these presentation colors.
	private var documentPalettePicker: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("DOCUMENT COLOR")
				.font(.caption.weight(.semibold))
				.tracking(0.7)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))

			HStack(spacing: 12) {
				ForEach(CardPalette.allCases) { palette in
					paletteSwatch(
						palette,
						isSelected: model.document.palette == palette,
						hint: "Sets this document's color."
					) {
						model.document.palette = palette
					}
				}
			}
		}
		.padding(14)
		.holderSurface(colorScheme)
		.accessibilityElement(children: .contain)
		.accessibilityLabel("Document color")
	}

	private func paletteSwatch(
		_ palette: CardPalette,
		isSelected: Bool,
		hint: String,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			Circle()
				.fill(HolderTheme.paletteColor(for: palette, identifier: model.document.id))
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
		.accessibilityLabel("\(palette.rawValue.capitalized) document color")
		.accessibilityValue(isSelected ? "Selected" : "Not selected")
		.accessibilityHint(hint)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}

	#if !os(macOS)
	private var iosDocumentView: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				if model.isAuthenticated {
					if model.isEditing {
						documentEditor
					} else {
						documentDetails
					}
				} else {
					lockedDocument
				}
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 18)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.scrollIndicators(.hidden)
		.navigationTitle(model.isNewDocument ? "New document" : model.document.title)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			if model.isNewDocument {
				ToolbarItem(placement: .topBarLeading) {
					Button("Cancel", action: cancelNewDocument)
						.holderTapTarget()
				}
			}
			ToolbarItem(placement: .topBarTrailing) {
				if model.isAuthenticated {
					if model.isEditing {
						Button("Done", action: finishEditing)
							.holderTapTarget()
					} else {
						Menu {
							Button("Edit", systemImage: "pencil") { model.isEditing = true }
							if onArchive != nil {
								Button("Archive", systemImage: "archivebox") { showArchiveConfirmation = true }
							}
							if onDelete != nil {
								Divider()
								Button("Delete", systemImage: "trash", role: .destructive) { showDeleteConfirmation = true }
							}
						} label: {
							Label("Document actions", systemImage: "ellipsis.circle")
						}
						.holderTapTarget()
					}
				}
			}
		}
		.interactiveDismissDisabled(model.isNewDocument)
	}
	#endif

	private var lockedDocument: some View {
		VStack(alignment: .leading, spacing: 18) {
			Image(systemName: "lock.doc.fill")
				.font(.system(size: 34, weight: .semibold))
				.foregroundStyle(HolderTheme.mintInk)
				.frame(width: 68, height: 68)
				.background(HolderTheme.mint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
			Text(model.document.title.isEmpty ? "New document" : model.document.title)
				.font(.title2.weight(.bold))
				.foregroundStyle(HolderTheme.primaryText(for: colorScheme))
			Text("\(model.document.kind.rawValue) is locked. Holder asks for Face ID, Touch ID, or your device passcode every time you open a document.")
				.font(.body)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
			Button(action: model.unlock) {
				if model.isAuthenticating {
					ProgressView().frame(maxWidth: .infinity, minHeight: 48)
				} else {
					Label("Unlock document", systemImage: "faceid")
						.frame(maxWidth: .infinity, minHeight: 48)
				}
			}
			.buttonStyle(.borderedProminent)
			.tint(HolderTheme.brandRaised)
			.disabled(model.isAuthenticating)
			.accessibilityHint("Authenticates with the device owner before showing document fields or photos.")
			Text("Photos are encrypted and stored on this device. They are never copied to iCloud by Holder.")
				.font(.footnote)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
		}
		.padding(22)
		.holderSurface(colorScheme, cornerRadius: HolderTheme.sheetCornerRadius)
	}

	private var documentDetails: some View {
		VStack(alignment: .leading, spacing: 16) {
			photoSlots
			HStack(alignment: .firstTextBaseline, spacing: 12) {
				Text("Photos stay on this device, encrypted. Tap a field to copy it.")
					.font(.footnote)
					.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
				Spacer(minLength: 8)
				#if os(iOS) && canImport(VisionKit)
				Menu {
					Button("Scan front", systemImage: "rectangle.portrait.and.arrow.forward") {
						beginDocumentScan(for: .front)
					}
					Button("Scan back", systemImage: "rectangle.portrait.and.arrow.forward") {
						beginDocumentScan(for: .back)
					}
				} label: {
					Label("Scan", systemImage: "doc.viewfinder")
				}
				.buttonStyle(.borderless)
				.foregroundStyle(HolderTheme.brandRaised)
				.accessibilityHint("Choose whether the first scanned page replaces the front or back photo.")
				#endif
			}

			if model.document.fields.isEmpty {
				ContentUnavailableView(
					"No fields yet",
					systemImage: "text.line.first.and.arrowtriangle.forward",
					description: Text("Edit this document to add typed fields such as its number or expiry date.")
				)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 18)
			} else {
				VStack(spacing: 0) {
					ForEach(Array(model.document.fields.enumerated()), id: \.element.id) { index, field in
						if index > 0 { Divider() }
						Button { model.copy(field) } label: {
							HStack(alignment: .firstTextBaseline, spacing: 12) {
								Text(field.displayLabel)
									.font(.subheadline)
									.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
									.frame(maxWidth: 116, alignment: .leading)
								Text(field.value)
									.font(.body.monospacedDigit())
									.foregroundStyle(HolderTheme.primaryText(for: colorScheme))
									.multilineTextAlignment(.trailing)
								Spacer(minLength: 6)
								Image(systemName: model.copiedFieldID == field.id ? "checkmark" : "doc.on.doc")
									.foregroundStyle(model.copiedFieldID == field.id ? HolderTheme.mintInk : HolderTheme.secondaryText(for: colorScheme))
							}
							.padding(14)
							.frame(maxWidth: .infinity, minHeight: 54)
						}
						.buttonStyle(.plain)
						.accessibilityLabel(model.copiedFieldID == field.id ? "\(field.displayLabel) copied" : field.displayLabel)
						.accessibilityValue(field.value)
						.accessibilityHint("Copies this field to the clipboard.")
					}
				}
				.holderSurface(colorScheme)
				.privacySensitive()
			}

			if onArchive != nil || onDelete != nil {
				managementSection
			}
		}
	}

	private var documentEditor: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text(model.isNewDocument ? "Save a document" : "Edit document")
				.font(.title2.weight(.bold))
				.foregroundStyle(HolderTheme.primaryText(for: colorScheme))
			Text("Photos are encrypted on this device. Keep payment cards separate so their existing iCloud Keychain storage stays unchanged.")
				.font(.footnote)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))

			VStack(spacing: 0) {
				editorRow("Title") {
					TextField("Driving licence", text: $model.document.title)
						.multilineTextAlignment(.trailing)
				}
				Divider()
				Picker("Document kind", selection: $model.document.kind) {
					ForEach(DocumentKind.allCases) { kind in
						Text(kind.rawValue).tag(kind)
					}
				}
				.padding(14)
			}
			.holderSurface(colorScheme)

			documentPalettePicker

			photoSlots
			photoPickers

			VStack(alignment: .leading, spacing: 10) {
				HStack {
					Text("TYPED FIELDS")
						.font(.caption.weight(.semibold))
						.tracking(0.7)
						.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
					Spacer()
					Button("Add field", systemImage: "plus") { model.addField() }
						.holderTapTarget()
				}
				if model.document.fields.isEmpty {
					Text("Add only the typed fields that help you identify or use this document.")
						.font(.footnote)
						.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
				} else {
					ForEach($model.document.fields) { $field in
						VStack(spacing: 0) {
							HStack {
								Picker("Field type", selection: $field.kind) {
									ForEach(DocumentFieldKind.allCases) { kind in
										Text(kind.rawValue).tag(kind)
									}
								}
								.labelsHidden()
								Spacer()
								Button("Remove \(field.displayLabel)", systemImage: "trash", role: .destructive) {
									model.removeField(id: field.id)
								}
								.labelStyle(.iconOnly)
								.frame(minWidth: 44, minHeight: 44)
							}
							Divider()
							TextField(field.kind == .custom ? "Field label" : field.displayLabel, text: Binding(
								get: { field.label ?? "" },
								set: { field.label = $0.isEmpty ? nil : $0 }
							))
								.textFieldStyle(.roundedBorder)
								.padding(14)
							if field.kind == .custom { Divider() }
							TextField("Value", text: $field.value, axis: .vertical)
								.textFieldStyle(.roundedBorder)
								.padding(14)
						}
						.holderSurface(colorScheme, cornerRadius: 14)
					}
				}
			}
		}
		.privacySensitive()
	}

	private var photoSlots: some View {
		HStack(spacing: 12) {
			DocumentPhotoSlot(side: .front, image: model.frontImage, isAvailable: model.frontImage != nil)
			DocumentPhotoSlot(side: .back, image: model.backImage, isAvailable: model.backImage != nil)
		}
		.privacySensitive()
	}

	#if !os(macOS)
	private var photoPickers: some View {
		VStack(spacing: 10) {
			HStack(spacing: 12) {
				photoPicker(side: .front, selection: $model.selectedFrontPhoto)
				photoPicker(side: .back, selection: $model.selectedBackPhoto)
			}
			#if os(iOS) && canImport(VisionKit)
			Menu {
				Button("Scan front", systemImage: "rectangle.portrait.and.arrow.forward") {
					beginDocumentScan(for: .front)
				}
				Button("Scan back", systemImage: "rectangle.portrait.and.arrow.forward") {
					beginDocumentScan(for: .back)
				}
			} label: {
				Label("Scan", systemImage: "doc.viewfinder")
					.frame(maxWidth: .infinity, minHeight: 44)
			}
			.buttonStyle(.borderedProminent)
			.tint(HolderTheme.brandRaised)
			.accessibilityLabel("Scan document")
			.accessibilityHint("Choose whether the first scanned page replaces the front or back photo.")
			#endif
			if model.document.hasFrontImage || model.document.hasBackImage {
				HStack(spacing: 12) {
					if model.document.hasFrontImage {
						Button("Remove front photo", systemImage: "trash", role: .destructive) {
							model.removeAttachment(.front)
						}
						.frame(maxWidth: .infinity, minHeight: 44)
					}
					if model.document.hasBackImage {
						Button("Remove back photo", systemImage: "trash", role: .destructive) {
							model.removeAttachment(.back)
						}
						.frame(maxWidth: .infinity, minHeight: 44)
					}
				}
			}
		}
	}

	private func photoPicker(side: DocumentAttachmentSide, selection: Binding<PhotosPickerItem?>) -> some View {
		PhotosPicker(selection: selection, matching: .images) {
			Label(model.document.hasImage(for: side) ? "Replace \(side.rawValue)" : "Add \(side.rawValue)", systemImage: "photo.badge.plus")
				.frame(maxWidth: .infinity, minHeight: 44)
		}
			.buttonStyle(.bordered)
			.onChange(of: selection.wrappedValue) { _, item in
				let authenticationGeneration = model.authenticationGeneration
				Task {
					guard let data = try? await item?.loadTransferable(type: Data.self) else {
						guard authenticationGeneration == model.authenticationGeneration,
							model.isAuthenticated else { return }
						model.errorMessage = "Holder could not read that photo."
						model.showsError = true
						return
					}
					model.saveAttachment(
						data,
						side: side,
						authenticationGeneration: authenticationGeneration
					)
				}
			}
			.accessibilityLabel("Add \(side.rawValue) document photo")
	}

	#if os(iOS) && canImport(VisionKit)
	private func beginDocumentScan(for side: DocumentAttachmentSide) {
		// The editor is rendered only after unlock, but retain this gate so a
		// delayed menu action can never present the camera from a locked view.
		guard model.isAuthenticated else { return }
		scannerRequest = DocumentScanRequest(
			side: side,
			authenticationGeneration: model.authenticationGeneration
		)
	}

	private func completeDocumentScan(_ data: Data, for request: DocumentScanRequest) {
		scannerRequest = nil
		model.saveAttachment(
			data,
			side: request.side,
			authenticationGeneration: request.authenticationGeneration
		)
	}

	private func handleDocumentScanFailure(for request: DocumentScanRequest) {
		scannerRequest = nil
		guard model.isAuthenticated,
			request.authenticationGeneration == model.authenticationGeneration else { return }
		model.errorMessage = "Holder could not read the scanned page. Try again."
		model.showsError = true
	}
	#endif
	#else
	private var photoPickers: some View {
		Text("Add photos on iPhone or iPad.")
			.font(.footnote)
			.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
	}
	#endif

	private var managementSection: some View {
		VStack(spacing: 0) {
			if onArchive != nil {
				Button("Archive document", systemImage: "archivebox") { showArchiveConfirmation = true }
					.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
					.padding(.horizontal, 16)
			}
			if onArchive != nil, onDelete != nil { Divider() }
			if onDelete != nil {
				Button("Delete document", systemImage: "trash", role: .destructive) { showDeleteConfirmation = true }
					.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
					.padding(.horizontal, 16)
			}
		}
		.holderSurface(colorScheme)
	}

	private func editorRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 12) {
			Text(label)
				.font(.subheadline)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
				.frame(maxWidth: 110, alignment: .leading)
			content()
				.foregroundStyle(HolderTheme.primaryText(for: colorScheme))
		}
		.padding(14)
		.frame(minHeight: 52)
	}

	private func finishEditing() {
		let operation: AppAnalyticsEvent.SaveOperation = model.isNewDocument ? .create : .update
		if model.persist() {
			track(.documentSaveCompleted(operation: operation))
			model.isEditing = false
			if model.isNewDocument { dismiss() }
		} else {
			track(.documentSaveFailed(operation: operation))
		}
	}

	private func cancelNewDocument() {
		if model.discardNewDocument() {
			dismiss()
		}
	}

	private func archiveDocument() {
		guard model.isAuthenticated else {
			model.unlock()
			return
		}
		guard let onArchive, onArchive(model.document) else {
			model.errorMessage = "Unable to archive this document. Try again."
			model.showsError = true
			return
		}
		dismiss()
	}

	private func deleteDocument() {
		guard model.isAuthenticated else {
			model.unlock()
			return
		}
		guard let onDelete, onDelete(model.document) else {
			model.errorMessage = "Unable to delete this document. Try again."
			model.showsError = true
			return
		}
		dismiss()
	}

	private func track(_ event: AppAnalyticsEvent) {
		Task { await analytics.capture(event) }
	}

	#if os(macOS)
	private var macOSDocumentView: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				if model.isAuthenticated {
					if model.isEditing { documentEditor } else { documentDetails }
				} else {
					lockedDocument
				}
			}
			.padding(24)
			.frame(maxWidth: 560)
			.frame(maxWidth: .infinity)
		}
		.navigationTitle(model.document.title)
		.toolbar {
			if model.isNewDocument {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel", action: cancelNewDocument)
				}
			}
			ToolbarItem(placement: .confirmationAction) {
				if model.isAuthenticated {
					if model.isEditing {
						Button("Done", action: finishEditing)
					} else {
						Menu {
							Button("Edit", systemImage: "pencil") { model.isEditing = true }
							if onArchive != nil {
								Button("Archive", systemImage: "archivebox") { showArchiveConfirmation = true }
							}
							if onDelete != nil {
								Button("Delete", systemImage: "trash", role: .destructive) { showDeleteConfirmation = true }
							}
						} label: {
							Label("Document actions", systemImage: "ellipsis.circle")
						}
					}
				}
			}
		}
	}
	#endif
}

#if os(iOS) && canImport(VisionKit)
private struct DocumentScanRequest: Identifiable {
	let id = UUID()
	let side: DocumentAttachmentSide
	let authenticationGeneration: UInt64
}
#endif

private struct DocumentPhotoSlot: View {
	let side: DocumentAttachmentSide
	let image: PlatformImage?
	let isAvailable: Bool

	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		VStack(spacing: 8) {
			Group {
				#if os(macOS)
				if let image {
					Image(nsImage: image)
						.resizable()
						.scaledToFill()
				} else {
					placeholder
				}
				#else
				if let image {
					Image(uiImage: image)
						.resizable()
						.scaledToFill()
				} else {
					placeholder
				}
				#endif
			}
			.frame(maxWidth: .infinity)
			.frame(height: 132)
			.clipped()
			.background(HolderTheme.softMint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
			.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
			.overlay {
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.stroke(HolderTheme.separator(for: colorScheme), lineWidth: 1)
			}
			Text(isAvailable ? "\(side.rawValue.capitalized) photo" : "No \(side.rawValue) photo")
				.font(.caption)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
		}
		.frame(maxWidth: .infinity)
		.accessibilityLabel(isAvailable ? "\(side.rawValue.capitalized) document photo" : "No \(side.rawValue) document photo")
	}

	private var placeholder: some View {
		VStack(spacing: 7) {
			Image(systemName: "doc.viewfinder")
				.font(.title2)
			Text(side.rawValue.capitalized)
				.font(.caption.weight(.semibold))
		}
		.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
	}
}
