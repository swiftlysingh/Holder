//
//  HomeView.swift
//  Holder
//

import SinghDevKit
import SwiftUI
import WhatsNewKit

struct HomeView: View {
	@StateObject private var model: HomeViewModel
	@Environment(\.analytics) private var analytics
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var showsAddChooser = false
	@State private var deckActionError: String?
	@State private var horizontalDeckOffsets: [String: CGFloat] = [:]

	private let deckPeek: CGFloat = 48
	private let deckCardHeight: CGFloat = 120

	init(
		cardDataStore: CardDataStore = CardDataStore(),
		documentDataStore: DocumentDataStore = DocumentDataStore()
	) {
		_model = StateObject(wrappedValue: HomeViewModel(
			cardDataStore: cardDataStore,
			documentDataStore: documentDataStore
		))
	}

	var body: some View {
		NavigationStack {
			ZStack(alignment: .bottomTrailing) {
				HolderTheme.background(for: colorScheme)
					.ignoresSafeArea()
				homeContent
				floatingAddButton
			}
			.navigationTitle("Holder")
			#if os(iOS)
			.navigationBarTitleDisplayMode(.large)
			#else
			.navigationDestination(item: $model.selectedItem) { destination in
				detail(for: destination)
			}
			#endif
			#if !os(macOS)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					NavigationLink {
						SettingsView(configuration: SettingsViewModel())
							.sdkScreen(AppAnalyticsScreen.settings)
					} label: {
						Label("Settings", systemImage: "gearshape")
					}
					.holderTapTarget()
				}
			}
			#endif
		}
		.task { model.loadItems() }
		.onOpenURL { url in
			model.handleDeepLink(url, onOpenedFromWidget: { track(.cardOpenedFromWidget) })
		}
		#if os(iOS)
		.sheet(item: $model.selectedItem) { destination in
			NavigationStack {
				detail(for: destination)
			}
			.presentationDetents([.medium, .large])
			.presentationDragIndicator(.visible)
			.presentationBackgroundInteraction(.enabled(upThrough: .medium))
		}
		#endif
		.confirmationDialog("Add to Holder", isPresented: $showsAddChooser, titleVisibility: .visible) {
			Button("Payment card", systemImage: "creditcard") {
				track(.cardAddStarted)
				model.addingKind = .card
			}
			Button("Document", systemImage: "doc.text.image") {
				track(.documentAddStarted)
				model.addingKind = .document
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("Cards keep their existing Keychain storage. Documents store encrypted photos on this device.")
		}
		.sheet(item: $model.addingKind) { kind in
			NavigationStack {
				switch kind {
				case .card:
					CardView(model: CardViewModel(
						card: CardData(
							id: UUID(),
							number: "",
							cvv: "",
							expiration: "",
								name: "",
								description: "",
								type: .creditCard,
								hasLegacyImage: false
						),
						isEditing: true,
						addNewFlow: true,
						addUpdateCard: { card in model.cardDataStore.addCard(card) }
					))
				case .document:
					DocumentView(model: DocumentViewModel(
						document: DocumentData(title: "", kind: .drivingLicence),
						documentStore: model.documentDataStore,
						isEditing: true,
						isNewDocument: true
					))
				}
			}
			#if os(iOS)
			.presentationDetents([.large])
			#endif
		}
		.alert("Protect Holder?", isPresented: model.$isFirstLaunch) {
			Button("Use device lock") { UserSettings.shared.isAuthEnabled = true }
			Button("Not now", role: .cancel) { UserSettings.shared.isAuthEnabled = false }
		} message: {
			Text("Cards stay masked until you unlock them. Documents always ask for the device owner when opened.")
		}
		.whatsNewSheet()
		.sdkScreen(AppAnalyticsScreen.home)
	}

	private var homeContent: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				filterBar
				if model.isSearching {
					searchField
				}
				if let error = deckActionError ?? model.loadingError {
					loadErrorBanner(error)
				}
				deckState
				if model.hasArchivedItems {
					NavigationLink {
						ArchivedCardsView(model: model)
					} label: {
						Label("Archived", systemImage: "archivebox")
							.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
							.padding(.horizontal, 16)
							.foregroundStyle(HolderTheme.primaryText(for: colorScheme))
					}
					.buttonStyle(.plain)
					.holderSurface(colorScheme)
				}
			}
			.padding(.horizontal, 20)
			.padding(.top, 8)
			.padding(.bottom, 106)
		}
		.refreshable { model.loadItems() }
	}

	private var filterBar: some View {
		HStack(spacing: 8) {
			ScrollView(.horizontal) {
				HStack(spacing: 8) {
					ForEach(VaultFilter.allCases) { filter in
						Button {
							model.filter = filter
						} label: {
							Text(filter.rawValue)
								.font(.subheadline.weight(.semibold))
								.foregroundStyle(model.filter == filter ? Color.white : HolderTheme.secondaryText(for: colorScheme))
								.padding(.horizontal, 14)
								.frame(minHeight: 34)
								.background(
									model.filter == filter
										? HolderTheme.brand
										: HolderTheme.raisedSurface(for: colorScheme),
									in: Capsule()
								)
								.overlay {
									Capsule().stroke(
										model.filter == filter ? .clear : HolderTheme.separator(for: colorScheme),
										lineWidth: 1
									)
								}
						}
						.buttonStyle(.plain)
						.frame(minHeight: 44)
						.accessibilityAddTraits(model.filter == filter ? .isSelected : [])
					}
				}
			}
			.scrollIndicators(.hidden)
			Button(action: toggleSearch) {
				Image(systemName: model.isSearching ? "xmark" : "magnifyingglass")
					.font(.subheadline.weight(.semibold))
					.frame(width: 44, height: 44)
					.background(HolderTheme.raisedSurface(for: colorScheme), in: Circle())
					.overlay { Circle().stroke(HolderTheme.separator(for: colorScheme), lineWidth: 1) }
			}
			.buttonStyle(.plain)
			.accessibilityLabel(model.isSearching ? "Close search" : "Search card labels and document names")
		}
	}

	private var searchField: some View {
		HStack(spacing: 10) {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
				TextField("Search labels or kinds", text: $model.searchText)
				.accessibilityLabel("Search card labels and documents")
			if !model.searchText.isEmpty {
				Button("Clear search", systemImage: "xmark.circle.fill") { model.searchText = "" }
					.labelStyle(.iconOnly)
					.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
					.frame(minWidth: 44, minHeight: 44)
			}
		}
		.padding(.horizontal, 14)
		.frame(minHeight: 48)
		.holderSurface(colorScheme, cornerRadius: 14)
	}

	@ViewBuilder
	private var deckState: some View {
		if model.isLoading && model.visibleItems.isEmpty {
			ProgressView("Loading Holder")
				.frame(maxWidth: .infinity, minHeight: 220)
				.tint(HolderTheme.brandRaised)
		} else if model.visibleItems.isEmpty {
			ContentUnavailableView(
				model.searchText.isEmpty ? "Your Holder is empty" : "No matching items",
				systemImage: model.searchText.isEmpty ? "rectangle.stack.badge.plus" : "magnifyingglass",
				description: Text(model.searchText.isEmpty
					? "Add a payment card or a document. Sensitive details stay masked until you unlock them."
						: "Search uses item labels and kinds — never card numbers or document fields.")
			)
			.frame(maxWidth: .infinity, minHeight: 240)
		} else {
			VStack(alignment: .leading, spacing: 12) {
				HStack {
					Text("YOUR DECK")
						.font(.caption.weight(.semibold))
						.tracking(0.8)
						.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
					Spacer()
					favoriteDropTarget
				}
				peekingDeck
			}
		}
	}

	/// A physical deck, not a list: every prior card leaves a 48-point exposed
	/// strip, widening toward the front card. Its explicit height lets the
	/// enclosing scroll view keep large collections navigable without hiding
	/// those exposed controls behind a fixed overlay.
	private var peekingDeck: some View {
		let items = model.visibleItems
		return ZStack(alignment: .top) {
			ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
				deckCard(for: item)
					.padding(.horizontal, deckInset(for: index, itemCount: items.count))
					.offset(x: horizontalDeckOffsets[item.id] ?? 0)
					.offset(y: CGFloat(index) * deckPeek)
					.zIndex(Double(index))
					.draggable(item.id) {
						Label(item.title, systemImage: item.isFavorite ? "star.fill" : "rectangle.stack.fill")
							.padding(12)
							.background(.regularMaterial, in: Capsule())
					}
					.dropDestination(for: String.self) { identifiers, _ in
						guard let sourceID = identifiers.first else { return false }
						return reorderDeckItem(withID: sourceID, before: item)
					}
					.simultaneousGesture(deckSwipeGesture(for: item))
					.contextMenu { deckContextMenu(for: item) }
					.accessibilityValue("\(index + 1) of \(items.count) in your deck")
					.accessibilitySortPriority(Double(items.count - index))
					.accessibilityAction(named: item.isFavorite ? "Remove from favorites" : "Add to favorites") {
						_ = model.toggleFavorite(item)
					}
					.accessibilityAction(named: "Archive") { _ = archiveDeckItem(item) }
			}
		}
		.frame(maxWidth: .infinity, alignment: .top)
		.frame(height: deckHeight(for: items.count), alignment: .top)
		.animation(reduceMotion ? nil : .snappy(duration: 0.28), value: items.map(\.id))
	}

	private var favoriteDropTarget: some View {
		Label("Favorites", systemImage: "star.fill")
			.font(.caption.weight(.semibold))
			.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
			.padding(.horizontal, 10)
			.frame(minHeight: 44)
			.background(HolderTheme.raisedSurface(for: colorScheme), in: Capsule())
			.overlay { Capsule().stroke(HolderTheme.separator(for: colorScheme), lineWidth: 1) }
			.dropDestination(for: String.self) { identifiers, _ in
				guard let itemID = identifiers.first,
					let item = model.visibleItems.first(where: { $0.id == itemID }) else {
					return false
				}
				return model.setFavorite(item, isFavorite: true)
			}
			.accessibilityHint("Drag a deck item here to add it to favorites.")
	}

	private func deckHeight(for itemCount: Int) -> CGFloat {
		guard itemCount > 0 else { return 0 }
		return deckCardHeight + CGFloat(itemCount - 1) * deckPeek
	}

	/// The rear card is inset most; each subsequent 48-point peek widens until
	/// the front card reaches the deck edges. Limit the visual depth at seven
	/// positions so long decks remain stable and deterministic.
	private func deckInset(for index: Int, itemCount: Int) -> CGFloat {
		let positionsBehindFront = max(0, itemCount - index - 1)
		let depth = min(positionsBehindFront, 6)
		return depth == 0 ? 0 : CGFloat(depth * 3 + 2)
	}

	private func toggleSearch() {
		let update = {
			model.isSearching.toggle()
			if !model.isSearching { model.searchText = "" }
		}
		if reduceMotion {
			update()
		} else {
			withAnimation(.easeInOut(duration: 0.18), update)
		}
	}

	private func deckCard(for item: VaultDeckItem) -> HolderDeckCard {
		switch item {
		case .card(let card):
			let compactNumber = card.number.replacingOccurrences(of: " ", with: "")
			let tail = String(compactNumber.suffix(4))
			return HolderDeckCard(
				title: card.displayLabel,
				identifier: card.id,
				isFavorite: card.isFavorite,
				artwork: .card(
					palette: card.palette,
					type: card.type,
					network: card.network,
					maskedTail: tail.isEmpty ? "Details masked" : "•••• \(tail)"
				)
			) {
				model.selectedItem = item.destination
			}
		case .document(let document):
			let photoCount = [document.hasFrontImage, document.hasBackImage].filter { $0 }.count
			return HolderDeckCard(
				title: document.title,
				identifier: document.id,
				isFavorite: document.isFavorite,
				artwork: .document(
					palette: document.palette,
					kind: document.kind,
					photoCount: photoCount
				)
			) {
				model.selectedItem = item.destination
			}
		}
	}

	private var canReorderDeck: Bool {
		model.filter == .all && model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	private func reorderDeckItem(withID sourceID: String, before target: VaultDeckItem) -> Bool {
		guard canReorderDeck else {
			deckActionError = "Show all items and clear search before reordering the deck."
			return false
		}
		var items = model.visibleItems
		guard let sourceIndex = items.firstIndex(where: { $0.id == sourceID }),
			let targetIndex = items.firstIndex(of: target),
			sourceIndex != targetIndex else {
			return false
		}
		let moved = items.remove(at: sourceIndex)
		let insertionIndex = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
		items.insert(moved, at: insertionIndex)
		let succeeded = model.updateDeckOrder(items)
		if succeeded { deckActionError = nil }
		return succeeded
	}

	private func moveDeckItem(_ item: VaultDeckItem, by offset: Int) {
		guard canReorderDeck else {
			deckActionError = "Show all items and clear search before reordering the deck."
			return
		}
		var items = model.visibleItems
		guard let sourceIndex = items.firstIndex(of: item) else { return }
		let destination = min(max(0, sourceIndex + offset), items.count - 1)
		guard sourceIndex != destination else { return }
		items.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destination > sourceIndex ? destination + 1 : destination)
		if model.updateDeckOrder(items) { deckActionError = nil }
	}

	private func archiveDeckItem(_ item: VaultDeckItem) -> Bool {
		let succeeded: Bool
		switch item {
		case .card(let card):
			succeeded = archiveCard(card)
		case .document(let document):
			succeeded = archiveDocument(document)
		}
		if succeeded {
			deckActionError = nil
			HapticService.trigger(.light)
		} else {
			deckActionError = "Holder could not archive that item. Try again."
			HapticService.trigger(.error)
		}
		return succeeded
	}

	private func deckSwipeGesture(for item: VaultDeckItem) -> some Gesture {
		DragGesture(minimumDistance: 24)
			.onChanged { value in
				guard value.translation.width < 0,
					abs(value.translation.width) > abs(value.translation.height) * 1.35 else { return }
				horizontalDeckOffsets[item.id] = max(-108, value.translation.width * 0.55)
			}
			.onEnded { value in
				let shouldArchive = value.translation.width < -110
					&& abs(value.translation.width) > abs(value.translation.height) * 1.35
				let reset: () -> Void = { _ = horizontalDeckOffsets.removeValue(forKey: item.id) }
				if reduceMotion { reset() }
				else { withAnimation(.snappy(duration: 0.22), reset) }
				if shouldArchive { _ = archiveDeckItem(item) }
			}
	}

	@ViewBuilder
	private func deckContextMenu(for item: VaultDeckItem) -> some View {
		Button(item.isFavorite ? "Remove from favorites" : "Add to favorites", systemImage: item.isFavorite ? "star.slash" : "star") {
			_ = model.toggleFavorite(item)
		}
		Button("Move earlier", systemImage: "arrow.up") { moveDeckItem(item, by: -1) }
			.disabled(!canReorderDeck)
		Button("Move later", systemImage: "arrow.down") { moveDeckItem(item, by: 1) }
			.disabled(!canReorderDeck)
		Divider()
		Button("Archive", systemImage: "archivebox") { _ = archiveDeckItem(item) }
	}

	private var floatingAddButton: some View {
		Button { showsAddChooser = true } label: {
			Image(systemName: "plus")
				.font(.title2.weight(.medium))
				.foregroundStyle(colorScheme == .dark ? .white : HolderTheme.brand)
				.frame(width: 56, height: 56)
				.background(.ultraThinMaterial, in: Circle())
				.overlay { Circle().stroke(.white.opacity(colorScheme == .dark ? 0.18 : 0.76), lineWidth: 1) }
				.shadow(color: .black.opacity(0.22), radius: 15, y: 8)
		}
		.buttonStyle(.plain)
		.padding(.trailing, 22)
		.padding(.bottom, 24)
		.accessibilityLabel("Add a card or document")
		.accessibilityHint("Choose whether to add a payment card or an encrypted document.")
	}

	private func loadErrorBanner(_ message: String) -> some View {
		HStack(alignment: .top, spacing: 10) {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(HolderTheme.warning)
			Text(message)
				.font(.footnote)
				.foregroundStyle(HolderTheme.secondaryText(for: colorScheme))
			Spacer(minLength: 8)
			Button("Retry") {
				deckActionError = nil
				model.loadItems()
			}
				.font(.footnote.weight(.semibold))
				.frame(minHeight: 44)
		}
		.padding(14)
		.holderSurface(colorScheme)
	}

	@ViewBuilder
	private func detail(for destination: VaultDestination) -> some View {
		switch destination {
		case .card(let id):
			if let card = model.cardDataStore.findCard(by: id) {
				CardView(
					model: CardViewModel(card: card, addUpdateCard: { model.cardDataStore.addCard($0) }),
					onArchive: archiveCard,
					onDelete: deleteCard,
					onMigrateLegacyImage: migrateLegacyImage
				)
				.id(id)
			} else {
				missingItem("This card is no longer available.")
			}
		case .document(let id):
			if let document = model.documentDataStore.document(with: id) {
				DocumentView(
					model: DocumentViewModel(document: document, documentStore: model.documentDataStore),
					onArchive: archiveDocument,
					onDelete: deleteDocument
				)
				.id(id)
			} else {
				missingItem("This document is no longer available.")
			}
		}
	}

	private func missingItem(_ description: String) -> some View {
		ContentUnavailableView("Item unavailable", systemImage: "questionmark.folder", description: Text(description))
	}

	private func archiveCard(_ card: CardData) -> Bool {
		let succeeded = model.archiveCard(card)
		track(succeeded ? .cardArchived : .cardArchiveFailed)
		return succeeded
	}

	private func deleteCard(_ card: CardData) -> Bool {
		let succeeded = model.deleteCard(card)
		track(succeeded ? .cardDeleted(location: .active) : .cardDeleteFailed(location: .active))
		return succeeded
	}

	private func migrateLegacyImage(
		_ card: CardData,
		_ kind: DocumentKind
	) -> Result<DocumentData, LegacyImageMigrationError> {
		let migration = LegacyImageMigrationService(
			documentStore: model.documentDataStore,
			loadSourceImageData: { ICloudDataManager.shared.loadImageData(for: $0) },
			deleteSourceCard: { model.cardDataStore.deleteCard(with: $0) }
		)
		do {
			return .success(try migration.migrate(card, as: kind))
		} catch let error as LegacyImageMigrationError {
			return .failure(error)
		} catch {
			return .failure(.destinationStoreFailed(.keychain(.unexpectedPayload)))
		}
	}

	private func archiveDocument(_ document: DocumentData) -> Bool {
		let succeeded = model.archiveDocument(document)
		track(succeeded ? .documentArchived : .documentArchiveFailed)
		return succeeded
	}

	private func deleteDocument(_ document: DocumentData) -> Bool {
		let succeeded = model.deleteDocument(document)
		track(succeeded ? .documentDeleted(location: .active) : .documentDeleteFailed(location: .active))
		return succeeded
	}

	private func track(_ event: AppAnalyticsEvent) {
		Task { await analytics.capture(event) }
	}
}
