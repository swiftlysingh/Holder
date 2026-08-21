//
//  ArchivedCardsView.swift
//  cards
//
//  View for displaying and managing archived cards
//

import SinghDevKit
import SwiftUI

struct ArchivedCardsView: View {
	@ObservedObject var model: HomeViewModel
	@Environment(\.analytics) private var analytics

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
								deleteCard(card)
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
								deleteCard(card)
							} label: {
								Label("Delete", systemImage: "trash")
							}
						}
				}
			}
		}
		.navigationTitle("Archived Cards")
		.toolbarTitleDisplayMode(.inlineLarge)
		.sdkScreen(AppAnalyticsScreen.archivedCards)
	}

	private func deleteCard(_ card: CardData) {
		let event: AppAnalyticsEvent = model.deleteArchivedCard(card)
			? .cardDeleted(location: .archived)
			: .cardDeleteFailed(location: .archived)
		track(event)
	}

	private func unarchiveCard(_ card: CardData) {
		let event: AppAnalyticsEvent = model.unarchiveCard(card)
			? .cardUnarchived
			: .cardUnarchiveFailed
		track(event)
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
				Text(card.number.toSecureCard())
					.foregroundStyle(.secondary)
			}
		}
	}
}
