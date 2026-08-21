//
//  ArchivedCardsView.swift
//  cards
//
//  View for displaying and managing archived cards
//

import SinghDevKit
import SwiftUI

@MainActor
struct ArchivedCardsView: View {
	@ObservedObject var model: HomeViewModel
	@EnvironmentObject private var authenticationSession: AuthenticationSession
	@Environment(\.analytics) private var analytics
	@State private var cardPendingDeletion: CardData?

	var body: some View {
		List {
			if model.cardDataStore.archivedCards.isEmpty {
				ContentUnavailableView(
					"No Archived Cards",
					systemImage: "archivebox",
					description: Text("Cards you archive will appear here")
				)
			} else {
				ForEach(model.cardDataStore.archivedCards) { card in
					cardRow(for: card)
						.swipeActions(edge: .trailing, allowsFullSwipe: false) {
							Button(role: .destructive) {
								cardPendingDeletion = card
							} label: {
								Label("Delete", systemImage: "trash")
							}
							Button {
								unarchiveCard(card)
							} label: {
								Label("Unarchive", systemImage: "arrow.uturn.backward")
							}
							.tint(.green)
						}
						.contextMenu {
							Button {
								unarchiveCard(card)
							} label: {
								Label("Unarchive", systemImage: "arrow.uturn.backward")
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
		.navigationTitle("Archived Cards")
		.toolbarTitleDisplayMode(.inlineLarge)
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
		.sdkScreen(AppAnalyticsScreen.archivedCards)
	}

	private func deleteCard(_ card: CardData) {
		Task { @MainActor in
			let event: AppAnalyticsEvent = await model.cardDataStore.deleteCard(with: card.id)
				? .cardDeleted(location: .archived)
				: .cardDeleteFailed(location: .archived)
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

	private func unarchiveCard(_ card: CardData) {
		Task { @MainActor in
			let event: AppAnalyticsEvent = await model.cardDataStore.unarchiveCard(card)
				? .cardUnarchived
				: .cardUnarchiveFailed
			track(event)
		}
	}

	private func track(_ event: AppAnalyticsEvent) {
		Task {
			await analytics.capture(event)
		}
	}

	private func cardRow(for card: CardData) -> some View {
		HStack {
			Image(card.network.rawValue)
				.resizable()
				.scaledToFit()
				.frame(width: 36, height: 36)

			VStack(alignment: .leading) {
				if !card.description.isEmpty {
					Text(card.description)
				} else {
					Text(card.name)
				}
				Text(card.number.maskedCardNumber())
					.foregroundStyle(.secondary)
			}
		}
	}
}
