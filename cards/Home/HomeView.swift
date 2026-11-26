import StoreKit
import SwiftUI
import SinghDevKit

@MainActor
struct HomeView: View {
	@ObservedObject private var model: HomeViewModel
	@ObservedObject private var appFlow: HolderAppFlow
	@EnvironmentObject private var authenticationSession: AuthenticationSession
	@Environment(\.payments) private var payments
	@Environment(\.requestReview) private var requestReview
	@Environment(\.scenePhase) private var scenePhase
	@Environment(\.supportPromptPolicy) private var supportPromptPolicy
	@Environment(\.analytics) private var analytics
	@Environment(\.sdk) private var sdk
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	private let privacyPolicyURL: URL?
	@State private var paymentsReady = false
	@State private var isShowingArchivedCards = false
	@State private var isOnboardingPresented = false
	@State private var isAddCardPresented = false
	@State private var cardPendingDeletion: CardData?
	@State private var hasAttemptedInitialCardLoad = false
	@State private var initialCardLoadSucceeded = false
	@State private var pendingOnboardingAddMode: CardEditorStartMode?
	#if os(macOS)
	@Environment(\.appearsActive) private var isMainWindowActive
	#else
	@State private var isShowingSettings = false
	@State private var isSettingsPresented = false
	#endif
	#if os(iOS)
	@State private var addCardSheetDetent: PresentationDetent = .height(430)
	#endif

	init(
		model: HomeViewModel,
		appFlow: HolderAppFlow,
		privacyPolicyURL: URL?
	) {
		self.model = model
		self.appFlow = appFlow
		self.privacyPolicyURL = privacyPolicyURL
	}

	var body: some View {
		NavigationSplitView {
			ZStack(alignment: .top) {
				homeBackground

				List(selection: $model.selectedCard) {
					ForEach(CardType.allCases) { type in
						let cards = model.cardDataStore.cardsByType[type] ?? []
						if !cards.isEmpty {
							Section(header: sectionHeader(for: type, count: cards.count)) {
								ForEach(cards, id: \.id) { card in
									getRowforCards(with: card)
										.swipeActions(edge: .trailing, allowsFullSwipe: false) {
											Button(role: .destructive) {
												cardPendingDeletion = card
											} label: {
												Label("Delete", systemImage: "trash")
											}
											Button {
												archiveCard(card)
											} label: {
												Label("Archive", systemImage: "archivebox")
											}
											.tint(.orange)
										}
										.contextMenu {
											Button {
												archiveCard(card)
											} label: {
												Label("Archive", systemImage: "archivebox")
											}
											Button(role: .destructive) {
												cardPendingDeletion = card
											} label: {
												Label("Delete", systemImage: "trash")
											}
										}
								}
							}
						}
					}
					if !model.cardDataStore.archivedCards.isEmpty {
						Section {
							NavigationLink {
								ArchivedCardsView(model: model)
									.onAppear { isShowingArchivedCards = true }
									.onDisappear { isShowingArchivedCards = false }
							} label: {
								HStack {
									Image(systemName: "archivebox")
									Text("View Archived Cards (\(model.cardDataStore.archivedCards.count))")
								}
							}
						}
					}
				}
				.scrollContentBackground(.hidden)
			}
			#if os(macOS)
			.navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 400)
			#endif
			.navigationTitle("Holder")
			.toolbarTitleDisplayMode(.inlineLarge)
			.task {
				defer { hasAttemptedInitialCardLoad = true }
				initialCardLoadSucceeded = await model.cardDataStore.loadCards()
			}
			#if os(iOS)
			// A bar item, not a floating button, so iPhone Duo can move it
			// to the vertical bar with the other controls.
			.toolbar {
				ToolbarItemGroup(placement: .bottomBar) {
					Spacer()
					addCardToolbarButton
				}
			}
			#else
			.toolbar {
				ToolbarItem {
					addCardButton
				}
			}
			#endif
			#if !os(macOS)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button("Settings", systemImage: "gear") {
						isShowingSettings = true
					}
				}
			}
			#endif
		} detail: {
			if let card = model.selectedCard {
				detailView(for: card, onClose: { model.selectedCard = nil })
			} else if hasActiveCards {
				ContentUnavailableView(
					"No Card Selected",
					systemImage: "creditcard",
					description: Text("Choose a card to see its details.")
				)
			} else {
				ContentUnavailableView(
					"No Cards",
					systemImage: "creditcard",
					description: Text("Cards you add will appear here.")
				)
			}
		}
		.onOpenURL { url in
			model.handleDeepLink(url, onOpenedFromWidget: {
				track(.cardOpenedFromWidget)
			})
		}
		.navigationDestination(item: $model.selectedCard) { card in
			detailView(for: card)
		}
		.sheet(isPresented: $model.isAddingCard, onDismiss: {
			isAddCardPresented = false
			model.revealPendingCardSelection()
		}) {
			let cardViewModel = CardViewModel(
				card: .init(id: UUID(),
						number: "",
						cvv: "",
						expiration: "",
						name: "",
						description: "",
						type: .credit
				   ),
				isEditing: true,
				addNewFlow: true,
				startMode: model.addCardStartMode,
				addUpdateCard: { card in
					await model.cardDataStore.addCard(card)
				},
				onSaved: { card, scanNumberUnedited in
					supportPromptPolicy?.recordNewCardSaved(
						id: card.id,
						scanNumberUnedited: scanNumberUnedited,
						activeCardCount: model.cardDataStore.activeCardCount
					)
					model.finishAddingCard(
						selecting: model.cardDataStore.findCard(by: card.id) ?? card
					)
				}
			)
			#if os(iOS)
			addCardSheetContent(cardViewModel)
				.presentationDetents(
					[.fraction(0.5), .height(430), .large],
					selection: $addCardSheetDetent
				)
				.presentationDragIndicator(.visible)
			#else
			NavigationView {
				CardView(model: cardViewModel)
			}
			#endif
		}
		.confirmationDialog(
			"Delete this card?",
			isPresented: Binding(
				get: { cardPendingDeletion != nil },
				set: { if !$0 { cardPendingDeletion = nil } }
			),
			presenting: cardPendingDeletion
		) { card in
			Button("Delete Card", role: .destructive) {
				authenticateAndDelete(card)
			}
		} message: { _ in
			Text("This cannot be undone.")
		}
		#if !os(macOS)
		.sheet(isPresented: $isShowingSettings, onDismiss: {
			isSettingsPresented = false
			presentPendingOnboardingReplayIfPossible()
		}) {
			NavigationStack {
				sdk.settingsView()
					.onAppear { isSettingsPresented = true }
					.sdkScreen(AppAnalyticsScreen.settings)
					.environment(
						\.holderOnboardingReplayAction,
						HolderOnboardingReplayAction {
							appFlow.requestOnboardingReplay()
							isShowingSettings = false
						}
					)
					.toolbar {
						ToolbarItem(placement: .confirmationAction) {
							// iPhone Duo's vertical bar only shows items with a symbol.
							if #available(iOS 26.0, visionOS 26.0, *) {
								Button(role: .close) {
									isShowingSettings = false
								}
							} else {
								Button("Done") {
									isShowingSettings = false
								}
							}
						}
					}
			}
		}
		#endif
		#if os(macOS)
		.onAppear(perform: presentPendingOnboardingReplayIfPossible)
		.onChange(of: appFlow.isOnboardingReplayPending) {
			presentPendingOnboardingReplayIfPossible()
		}
		.onChange(of: model.isAddingCard) {
			presentPendingOnboardingReplayIfPossible()
		}
		#endif
		.onboardingPresentation(
			audience: onboardingAudience,
			hasStoredCards: initialCardLoadSucceeded ? hasStoredCards : nil,
			privacyPolicyURL: privacyPolicyURL,
			onPresented: { audience in
				isOnboardingPresented = true
				track(.onboardingShown(audience: audience))
			},
			onSkip: { audience in
				finishOnboarding(audience, outcome: .skipped)
			},
			onStartAddingCard: { audience, mode in
				pendingOnboardingAddMode = mode
				let outcome: AppAnalyticsEvent.OnboardingOutcome = mode == .scanner ? .scanner : .manual
				finishOnboarding(audience, outcome: outcome)
			},
			onDismiss: onboardingDidDismiss
		)
		.onChange(of: model.isAddingCard) { _, isPresented in
			if isPresented { isAddCardPresented = true }
		}
		.onChange(of: model.selectedCard?.id) { previous, current in
			guard let previous, current == nil, canPresentPrompt,
				  model.cardDataStore.findCard(by: previous) != nil else { return }
			supportPromptPolicy?.returnedFromCardDetails()
		}
		.onChange(of: isCardListAvailable) { _, canStay in
			if !canStay { supportPromptPolicy?.leftCardList() }
		}
		.onChange(of: isPromptWindowActive) { _, isActive in
			if !isActive, supportPromptPolicy?.automaticTip == nil {
				supportPromptPolicy?.leftCardList()
			}
		}
		.onDisappear { supportPromptPolicy?.leftCardList() }
		.background { automaticTipPresenter }
		.onReceive(sdk.$configurationState) { state in
			paymentsReady = state == .configured
		}
		.task(id: listPrompt) {
			guard let prompt = listPrompt else { return }
			// Let the cards list settle after navigation or a sheet dismissal.
			try? await Task.sleep(for: .milliseconds(350))
			await presentListPrompt(prompt)
		}
		.sdkScreen(AppAnalyticsScreen.home)
	}

	private let reviewVersion = Bundle.main.versionNumber

	private func detailView(for card: CardData, onClose: (() -> Void)? = nil) -> some View {
		CardView(
			model: CardViewModel(
				card: card,
				addUpdateCard: { card in await model.cardDataStore.updateCard(card) }
			),
			onClose: onClose
		)
		.id(card.id)
		.onAppear { supportPromptPolicy?.showedCardDetails(id: card.id) }
	}

	@ViewBuilder
	private var automaticTipPresenter: some View {
		if let supportPromptPolicy, let attempt = supportPromptPolicy.automaticTip {
			Color.clear
				// presentListPrompt already checked every tip entitlement.
				// The SDK fetches the offering before presenting it.
				.presentSDKPaywallIfNeeded(
					requiredEntitlement: "",
					presentationMode: .sheet,
					analyticsContext: SDKPaywallContext(source: attempt.source.rawValue),
					onDismiss: { supportPromptPolicy.dismissAutomaticTip(attempt) }
				)
				.id(attempt.id)
		}
	}

	private var isPromptWindowActive: Bool {
		#if os(macOS)
		guard isMainWindowActive else { return false }
		#endif
		return scenePhase == .active && !authenticationSession.isPrivacyCurtainVisible
	}

	private var isCardListAvailable: Bool {
		#if !os(macOS)
		guard !isShowingSettings && !isSettingsPresented else { return false }
		#endif
		return initialCardLoadSucceeded && model.selectedCard == nil && !isShowingArchivedCards
			&& authenticationSession.isVaultUnlocked && !authenticationSession.isAuthenticating
			&& !isOnboardingPresented && appFlow.onboardingAudience == nil && !appFlow.isOnboardingReplayPending
			&& pendingOnboardingAddMode == nil && !model.isAddingCard && !isAddCardPresented
			&& cardPendingDeletion == nil
	}

	private var canPresentPrompt: Bool { isCardListAvailable && isPromptWindowActive }

	private var listPrompt: SupportPromptPolicy.Prompt? {
		guard let prompt = supportPromptPolicy?.nextPrompt(
			version: reviewVersion,
			canPresent: canPresentPrompt,
			tipsEnabled: sdk.configuration?.payments != .disabled
		) else { return nil }
		if case .tip = prompt, !paymentsReady { return nil }
		return prompt
	}

	private func presentListPrompt(_ prompt: SupportPromptPolicy.Prompt) async {
		guard let supportPromptPolicy, !Task.isCancelled, listPrompt == prompt else { return }
		var hasPurchasedTip: Bool?
		if case .tip = prompt, await payments.isConfigured {
			// Holder's permanent tip entitlements include past purchases.
			let entitlements = try? await payments.activeEntitlements()
			hasPurchasedTip = entitlements.map { !$0.isEmpty }
		}
		guard !Task.isCancelled, listPrompt == prompt else { return }
		if supportPromptPolicy.claim(prompt, version: reviewVersion, hasPurchasedTip: hasPurchasedTip),
		   prompt == .review {
			requestReview()
		}
	}

	private var homeBackground: some View {
		ZStack(alignment: .top) {
			groupedBackground
			RadialGradient(
				colors: [
					Color.accentColor.opacity(reduceTransparency ? 0.09 : 0.27),
					Color.accentColor.opacity(reduceTransparency ? 0.04 : 0.11),
					.clear
				],
				center: .top,
				startRadius: 0,
				endRadius: 340
			)
			.frame(height: 340)
			.blur(radius: reduceTransparency ? 0 : 34)
			.allowsHitTesting(false)
		}
		.ignoresSafeArea()
	}

	private var groupedBackground: Color {
		#if os(macOS)
		Color(nsColor: .windowBackgroundColor)
		#else
		Color(uiColor: .systemGroupedBackground)
		#endif
	}

	private var addCardButton: some View {
		Button {
			beginAddingCard(with: .scanner, source: .home)
		} label: {
			Label("Add Card", systemImage: "plus")
		}
	}

	#if os(iOS)
	@ViewBuilder
	private var addCardToolbarButton: some View {
		if #available(iOS 26.0, *) {
			addCardButton
				.buttonStyle(.borderedProminent)
				.tint(.accentColor)
		} else {
			addCardButton
		}
	}

	private func addCardSheetContent(_ cardViewModel: CardViewModel) -> some View {
		CardView(
			model: cardViewModel,
			cardSheetDetent: $addCardSheetDetent
		)
	}
	#endif

	private var onboardingAudience: Binding<HolderOnboardingAudience?> {
		Binding(
			get: {
				#if os(macOS)
				appFlow.visibleOnboardingAudience(
					hasAttemptedInitialCardLoad: hasAttemptedInitialCardLoad,
					isAddingCard: model.isAddingCard
				)
				#else
				appFlow.visibleOnboardingAudience(
					hasAttemptedInitialCardLoad: hasAttemptedInitialCardLoad,
					isAddingCard: model.isAddingCard,
					isShowingSettings: isShowingSettings
				)
				#endif
			},
			set: { appFlow.onboardingAudience = $0 }
		)
	}

	private var hasActiveCards: Bool {
		model.cardDataStore.cardsByType.values.contains { !$0.isEmpty }
	}

	private var hasStoredCards: Bool {
		hasActiveCards || !model.cardDataStore.archivedCards.isEmpty
	}

	private func beginAddingCard(
		with mode: CardEditorStartMode,
		source: AppAnalyticsEvent.CardAddSource
	) {
		track(.cardAddStarted(source: source))
		model.addCardStartMode = mode
		#if os(iOS)
		addCardSheetDetent = mode == .scanner ? .height(430) : .fraction(0.5)
		#endif
		model.isAddingCard = true
	}

	private func finishOnboarding(
		_ audience: HolderOnboardingAudience,
		outcome: AppAnalyticsEvent.OnboardingOutcome
	) {
		track(.onboardingCompleted(audience: audience, outcome: outcome))
		appFlow.completeOnboarding(for: audience)
	}

	private func presentPendingOnboardingAddCard() {
		guard let mode = pendingOnboardingAddMode else { return }
		pendingOnboardingAddMode = nil
		beginAddingCard(with: mode, source: .onboarding)
	}

	private func onboardingDidDismiss() {
		isOnboardingPresented = false
		presentPendingOnboardingAddCard()
		#if os(macOS)
		presentPendingOnboardingReplayIfPossible()
		#endif
	}

	private func presentPendingOnboardingReplayIfPossible() {
		appFlow.presentPendingOnboardingReplay(canPresent: !model.isAddingCard)
	}

	private func deleteCard(_ card: CardData) {
		Task { @MainActor in
			let event: AppAnalyticsEvent = await model.cardDataStore.deleteCard(with: card.id)
				? .cardDeleted(location: .active)
				: .cardDeleteFailed(location: .active)
			track(event)
		}
	}

	private func authenticateAndDelete(_ card: CardData) {
		authenticationSession.authenticateForSensitiveAccess(
			reason: "Authenticate to delete this card."
		) { success in
			guard success else { return }
			deleteCard(card)
			cardPendingDeletion = nil
		}
	}

	private func archiveCard(_ card: CardData) {
		Task { @MainActor in
			let event: AppAnalyticsEvent = await model.cardDataStore.archiveCard(card)
				? .cardArchived
				: .cardArchiveFailed
			track(event)
		}
	}

	private func track(_ event: AppAnalyticsEvent) {
		Task {
			await analytics.capture(event)
		}
	}

	private func getRowforCards(with card: CardData) -> some View {
		NavigationLink(value: card) {
			HStack(spacing: 12) {
				cardArtwork(for: card)

				VStack(alignment: .leading, spacing: 3) {
					Text(card.description.isEmpty ? card.name : card.description)
						.font(.body.weight(.semibold))
						.foregroundStyle(.primary)
						.lineLimit(2)
						.withoutInterpolatingText()

					Text(card.number.maskedCardNumber())
						.font(.footnote)
						.foregroundStyle(.secondary)
						.monospacedDigit()
						.withoutInterpolatingText()
				}
			}
			.padding(.vertical, 2)
		}
	}

	private func sectionHeader(for type: CardType, count: Int) -> some View {
		HStack {
			Text(type.rawValue)
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(.primary)
			Spacer()
			Text("\(count) card\(count == 1 ? "" : "s")")
				.font(.caption2.weight(.medium))
				.foregroundStyle(.secondary)
				.padding(.horizontal, 8)
				.padding(.vertical, 4)
				.background(.quaternary, in: Capsule())
		}
		.textCase(nil)
	}

	private func cardArtwork(for card: CardData) -> some View {
		Image(cardArtworkName(for: card.network))
			.resizable()
			.scaledToFill()
			.frame(width: 56, height: 38)
			.clipped()
			.clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
			.overlay {
				RoundedRectangle(cornerRadius: 6, style: .continuous)
					.stroke(.white.opacity(0.1), lineWidth: 0.5)
			}
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(Text(card.network == .other ? "Card" : cardNetworkLabel(for: card.network)))
	}

	private func cardNetworkLabel(for network: CardNetwork) -> String {
		network == .rupay ? "RuPay" : network.rawValue
	}

	private func cardArtworkName(for network: CardNetwork) -> String {
		switch network {
		case .visa:
			return "CardArtworkVisa"
		case .master:
			return "CardArtworkMastercard"
		case .amex:
			return "CardArtworkAmex"
		case .diners:
			return "CardArtworkDiners"
		case .rupay:
			return "CardArtworkRuPay"
		case .discover:
			return "CardArtworkDiscover"
		case .jcb:
			return "CardArtworkJCB"
		case .unionPay:
			return "CardArtworkUnionPay"
		case .other:
			return "CardArtworkOther"
		}
	}
}
