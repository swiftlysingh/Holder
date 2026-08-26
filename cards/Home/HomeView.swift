//
//  ContentView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI
import WhatsNewKit
import SinghDevKit

@MainActor
struct HomeView: View {
	@ObservedObject private var model: HomeViewModel
	@EnvironmentObject private var authenticationSession: AuthenticationSession
	@Environment(\.analytics) private var analytics
	@Environment(\.sdk) private var sdk
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@State private var cardPendingDeletion: CardData?
	#if !os(macOS)
	@State private var isShowingSettings = false
	#endif
	#if os(iOS)
	@State private var addCardSheetDetent: PresentationDetent = .height(430)
	@Namespace private var addCardTransition
	#endif

	init(model: HomeViewModel) {
		self.model = model
	}

	var body: some View {
		NavigationSplitView {
			ZStack(alignment: .top) {
				homeBackground

				List(selection: $model.selectedCard) {
					ForEach(CardType.allCases) { type in
						let cards = model.cardDataStore.cardsByType[type] ?? []
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
					// Archived Cards Link
					if !model.cardDataStore.archivedCards.isEmpty {
						Section {
							NavigationLink {
								ArchivedCardsView(model: model)
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
			.navigationTitle("Cards")
			.toolbarTitleDisplayMode(.inlineLarge)
			.task {
				await model.cardDataStore.loadCards()
			}
			#if os(iOS)
			.safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
				floatingAddCardButton
					.padding(.trailing, 16)
					.padding(.bottom, 8)
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
					Button {
						isShowingSettings = true
					} label: {
						Image(systemName: "gear")
					}
				}
			}
			#endif
		} detail: {
			if let card = model.selectedCard {
				CardView(model: CardViewModel(
								card: card,
								addUpdateCard: { card in
									await model.cardDataStore.updateCard(card)
								}))
					.id(card.id)
			} 
			else {
				Text("Tap on a Card to view details")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.background(Color.appBackground)
			}
		}
		.background(Color.appBackground)
		.whatsNewSheet()
		.onOpenURL { url in
			model.handleDeepLink(url, onOpenedFromWidget: {
				track(.cardOpenedFromWidget)
			})
		}
		.navigationDestination(item: $model.selectedCard) { card in
			CardView(model: CardViewModel(
				card: card,
				addUpdateCard: { card in
					await model.cardDataStore.updateCard(card)
				}))
			.id(card.id)
		}
		.sheet(isPresented: $model.isAddingCard) {
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
				addUpdateCard: { card in
					// Keep the sheet open on failure so the entered form is preserved for retry.
					let succeeded = await model.cardDataStore.addCard(card)
					if succeeded {
						model.isAddingCard = false
					}
					return succeeded
				}
			)
			#if os(iOS)
			Group {
				if #available(iOS 18.0, *) {
					addCardSheetContent(cardViewModel)
						.navigationTransition(
							.zoom(sourceID: "add-card", in: addCardTransition)
						)
				} else {
					addCardSheetContent(cardViewModel)
				}
			}
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
		.sheet(isPresented: $isShowingSettings) {
			NavigationStack {
				sdk.settingsView()
					.sdkScreen(AppAnalyticsScreen.settings)
					.toolbar {
						ToolbarItem(placement: .confirmationAction) {
							Button("Done") {
								isShowingSettings = false
							}
						}
					}
			}
		}
		#endif
		.sdkScreen(AppAnalyticsScreen.home)
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
		Color.appBackground
	}

	private var addCardButton: some View {
		Button(action: beginAddingCard) {
			Label("Add Card", systemImage: "plus")
		}
	}

	#if os(iOS)
	@ViewBuilder
	private var floatingAddCardButton: some View {
		let button = addCardButton
			.labelStyle(.iconOnly)
			.buttonBorderShape(.circle)
			.controlSize(.large)
			.tint(.accentColor)

		if #available(iOS 26.0, *) {
			button
				.buttonStyle(.glassProminent)
				.matchedTransitionSource(id: "add-card", in: addCardTransition)
		} else if #available(iOS 18.0, *) {
			button
				.buttonStyle(.borderedProminent)
				.matchedTransitionSource(id: "add-card", in: addCardTransition)
		} else {
			button
				.buttonStyle(.borderedProminent)
		}
	}

	private func addCardSheetContent(_ cardViewModel: CardViewModel) -> some View {
		CardView(
			model: cardViewModel,
			cardSheetDetent: $addCardSheetDetent
		)
	}
	#endif

	private func beginAddingCard() {
		track(.cardAddStarted)
		#if os(iOS)
		addCardSheetDetent = .height(430)
		#endif
		model.isAddingCard = true
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

					Text(card.number.maskedCardNumber())
						.font(.footnote)
						.foregroundStyle(.secondary)
						.monospacedDigit()
				}
			}
			.padding(.vertical, 2)
		}
	}

	private func sectionHeader(for type: CardType, count: Int) -> some View {
		HStack {
			Text("\(type.rawValue)s")
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
