//
//  ArchivedCardsView.swift
//  Holder
//

import SinghDevKit
import SwiftUI

struct ArchivedCardsView: View {
	@ObservedObject var model: HomeViewModel
	@Environment(\.analytics) private var analytics
	@Environment(\.colorScheme) private var colorScheme
	@State private var errorMessage: String?

	var body: some View {
		List {
			if model.cardDataStore.archivedCards.isEmpty && model.documentDataStore.archivedDocuments.isEmpty {
				ContentUnavailableView(
					"Nothing archived",
					systemImage: "archivebox",
					description: Text("Archived cards and documents stay here until you restore or delete them.")
				)
				.listRowBackground(Color.clear)
			} else {
					if !model.cardDataStore.archivedCards.isEmpty {
						Section("Cards") {
							ForEach(model.cardDataStore.archivedCards) { card in
								NavigationLink {
									CardView(
										model: CardViewModel(
											card: card,
											addUpdateCard: { model.cardDataStore.addCard($0) }
										),
										onDelete: deleteCard,
										onMigrateLegacyImage: migrateLegacyImage
									)
								} label: {
									cardRow(card)
								}
									.swipeActions(edge: .trailing, allowsFullSwipe: false) {
										Button { unarchiveCard(card) } label: {
											Label("Restore", systemImage: "arrow.uturn.backward")
										}
									.tint(HolderTheme.brandRaised)
								}
									.contextMenu {
										Button("Restore", systemImage: "arrow.uturn.backward") { unarchiveCard(card) }
									}
							}
					}
				}

					if !model.documentDataStore.archivedDocuments.isEmpty {
						Section("Documents") {
							ForEach(model.documentDataStore.archivedDocuments) { document in
								NavigationLink {
									DocumentView(
										model: DocumentViewModel(
											document: document,
											documentStore: model.documentDataStore
										),
										onDelete: deleteDocument
									)
								} label: {
									documentRow(document)
								}
									.swipeActions(edge: .trailing, allowsFullSwipe: false) {
										Button { unarchiveDocument(document) } label: {
											Label("Restore", systemImage: "arrow.uturn.backward")
										}
									.tint(HolderTheme.brandRaised)
								}
									.contextMenu {
										Button("Restore", systemImage: "arrow.uturn.backward") { unarchiveDocument(document) }
									}
						}
					}
				}
			}
		}
		.scrollContentBackground(.hidden)
		.background(HolderTheme.background(for: colorScheme))
		.navigationTitle("Archived")
		.alert("Archive error", isPresented: Binding(
			get: { errorMessage != nil },
			set: { if !$0 { errorMessage = nil } }
		)) {
			Button("OK", role: .cancel) { errorMessage = nil }
		} message: {
			Text(errorMessage ?? "Holder could not complete that action.")
		}
		.sdkScreen(AppAnalyticsScreen.archivedCards)
	}

	private func cardRow(_ card: CardData) -> some View {
		let title = card.displayLabel
		let tail = String(card.number.replacingOccurrences(of: " ", with: "").suffix(4))
		return HStack(spacing: 12) {
			Image(systemName: "creditcard.fill")
				.foregroundStyle(HolderTheme.mintInk)
				.frame(width: 34, height: 34)
				.background(HolderTheme.softMint, in: Circle())
			VStack(alignment: .leading, spacing: 3) {
				Text(title)
					.font(.body.weight(.medium))
				Text(tail.isEmpty ? "Details masked" : "•••• \(tail)")
					.font(.subheadline.monospacedDigit())
					.foregroundStyle(.secondary)
			}
			Spacer()
			Text(card.type == .loyaltyCard ? "LOYALTY" : card.type == .travelCard ? "TRAVEL" : "CARD")
				.font(.caption2.weight(.semibold))
				.tracking(0.6)
				.foregroundStyle(.secondary)
		}
		.padding(.vertical, 4)
		.accessibilityLabel("Archived card, \(title)")
	}

	private func documentRow(_ document: DocumentData) -> some View {
		HStack(spacing: 12) {
			Image(systemName: "doc.text.image")
				.foregroundStyle(HolderTheme.mintInk)
				.frame(width: 34, height: 34)
				.background(HolderTheme.softMint, in: Circle())
			VStack(alignment: .leading, spacing: 3) {
				Text(document.title)
					.font(.body.weight(.medium))
				Text(document.kind.rawValue)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			Spacer()
			Text("DOCUMENT")
				.font(.caption2.weight(.semibold))
				.tracking(0.6)
				.foregroundStyle(.secondary)
		}
		.padding(.vertical, 4)
		.accessibilityLabel("Archived document, \(document.title)")
	}

	private func unarchiveCard(_ card: CardData) {
		let succeeded = model.unarchiveCard(card)
		track(succeeded ? .cardUnarchived : .cardUnarchiveFailed)
		if !succeeded { errorMessage = "Unable to restore this card. Try again." }
	}

	private func deleteCard(_ card: CardData) -> Bool {
		let succeeded = model.deleteCard(card)
		track(succeeded ? .cardDeleted(location: .archived) : .cardDeleteFailed(location: .archived))
		if !succeeded { errorMessage = "Unable to delete this card. Try again." }
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

	private func unarchiveDocument(_ document: DocumentData) {
		let succeeded = model.unarchiveDocument(document)
		track(succeeded ? .documentUnarchived : .documentUnarchiveFailed)
		if !succeeded {
			errorMessage = "Unable to restore this document. Try again."
		}
	}

	private func deleteDocument(_ document: DocumentData) -> Bool {
		let succeeded = model.deleteDocument(document)
		track(succeeded ? .documentDeleted(location: .archived) : .documentDeleteFailed(location: .archived))
		if !succeeded {
			errorMessage = "Unable to delete this document. Try again."
		}
		return succeeded
	}

	private func track(_ event: AppAnalyticsEvent) {
		Task { await analytics.capture(event) }
	}
}
