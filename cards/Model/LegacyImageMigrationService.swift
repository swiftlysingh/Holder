//
//  LegacyImageMigrationService.swift
//  Holder
//
//  An explicitly user-invoked path from a legacy Other Card image into the
//  encrypted, device-local document vault. It intentionally has no automatic
//  classification or launch-time migration behavior.
//

import Foundation

enum LegacyImageMigrationError: Error, LocalizedError, Equatable {
	case sourceIsNotOtherCard
	case sourceImageUnavailable
	case existingDestinationIsNotVerified
	case destinationStoreFailed(DocumentDataStoreError)
	case destinationVerificationFailed
	/// The encrypted document was verified, but the legacy card (and its legacy
	/// iCloud image) could not be deleted. Retry with the same card and kind;
	/// the verified destination will be reused without rewriting it.
	case sourceDeletionFailed(document: DocumentData)

	var isRetryable: Bool {
		switch self {
		case .sourceImageUnavailable,
			 .destinationStoreFailed,
			 .destinationVerificationFailed,
			 .sourceDeletionFailed:
			return true
		case .sourceIsNotOtherCard,
			 .existingDestinationIsNotVerified:
			return false
		}
	}

	var recoveredDocument: DocumentData? {
		guard case .sourceDeletionFailed(let document) = self else { return nil }
		return document
	}

	var errorDescription: String? {
		switch self {
		case .sourceIsNotOtherCard:
			return "Only legacy Other Cards can be moved into a document."
		case .sourceImageUnavailable:
			return "Holder could not read the legacy image. The card was not changed."
		case .existingDestinationIsNotVerified:
			return "A document with this card’s identifier already exists but cannot be verified. The card was not changed."
		case .destinationStoreFailed:
			return "Holder could not encrypt and save the document. The card was not changed."
		case .destinationVerificationFailed:
			return "Holder could not verify the encrypted document. The card was not changed."
		case .sourceDeletionFailed:
			return "The encrypted document is safe, but Holder could not remove the legacy card. Retry to finish the move."
		}
	}
}

/// Coordinates a one-way, user-confirmed move of a legacy `Other Card` image.
///
/// The caller supplies the selected `DocumentKind`, raw source bytes, and a
/// deletion closure. The deletion closure must return `true` only after it has
/// removed both the legacy card metadata and its associated compatibility image.
/// Keeping those dependencies injected makes this service usable from UI code
/// without coupling the encrypted document vault to the legacy iCloud client.
@MainActor
final class LegacyImageMigrationService {
	typealias SourceImageDataLoader = (UUID) -> Data?
	typealias SourceCardDeleter = (UUID) -> Bool

	private let documentStore: DocumentDataStore
	private let loadSourceImageData: SourceImageDataLoader
	private let deleteSourceCard: SourceCardDeleter

	init(
		documentStore: DocumentDataStore,
		loadSourceImageData: @escaping SourceImageDataLoader,
		deleteSourceCard: @escaping SourceCardDeleter
	) {
		self.documentStore = documentStore
		self.loadSourceImageData = loadSourceImageData
		self.deleteSourceCard = deleteSourceCard
	}

	/// Moves the selected legacy card image into the encrypted document vault.
	/// No source record is deleted until a front attachment has been encrypted,
	/// persisted, and read back byte-for-byte. Supplying `kind` is deliberate:
	/// this service never guesses a document type from card metadata or pixels.
	@discardableResult
	func migrate(_ card: CardData, as kind: DocumentKind) throws -> DocumentData {
		guard card.type == .otherCard else {
			throw LegacyImageMigrationError.sourceIsNotOtherCard
		}

		let expectedDocument = makeDocument(from: card, kind: kind)
		if let existingDocument = documentStore.document(with: card.id) {
			let verifiedDocument = try verifyExistingDestination(
				existingDocument,
				expectedDocument: expectedDocument
			)

			// A previous source deletion can fail after the iCloud image was already
			// removed but before the card metadata was removed. In that retry state,
			// the verified same-ID destination is sufficient to safely retry source
			// deletion; requiring bytes that are already gone would strand the card.
			if let sourceData = loadSourceImageData(card.id) {
				guard !sourceData.isEmpty else {
					throw LegacyImageMigrationError.sourceImageUnavailable
				}
				guard try attachmentData(for: verifiedDocument) == sourceData else {
					throw LegacyImageMigrationError.destinationVerificationFailed
				}
			}

			return try deleteVerifiedSourceCard(for: verifiedDocument)
		}

		guard let sourceData = loadSourceImageData(card.id), !sourceData.isEmpty else {
			throw LegacyImageMigrationError.sourceImageUnavailable
		}

		do {
			let persistedDocument = try documentStore.saveAttachment(
				sourceData,
				for: expectedDocument,
				side: .front
			)
			guard try attachmentData(for: persistedDocument) == sourceData else {
				throw LegacyImageMigrationError.destinationVerificationFailed
			}
			return try deleteVerifiedSourceCard(for: persistedDocument)
		} catch let error as LegacyImageMigrationError {
			throw error
		} catch let error as DocumentDataStoreError {
			throw LegacyImageMigrationError.destinationStoreFailed(error)
		} catch {
			throw LegacyImageMigrationError.destinationStoreFailed(.keychain(.unexpectedPayload))
		}
	}

	private func verifyExistingDestination(
		_ document: DocumentData,
		expectedDocument: DocumentData
	) throws -> DocumentData {
		guard matchesExpectedMigrationMetadata(document, expected: expectedDocument),
			document.hasFrontImage else {
			throw LegacyImageMigrationError.existingDestinationIsNotVerified
		}
		guard !(try attachmentData(for: document)).isEmpty else {
			throw LegacyImageMigrationError.existingDestinationIsNotVerified
		}
		return document
	}

	private func attachmentData(for document: DocumentData) throws -> Data {
		do {
			guard let data = try documentStore.attachmentData(for: document.id, side: .front) else {
				throw LegacyImageMigrationError.destinationVerificationFailed
			}
			return data
		} catch let error as LegacyImageMigrationError {
			throw error
		} catch let error as DocumentDataStoreError {
			throw LegacyImageMigrationError.destinationStoreFailed(error)
		} catch {
			throw LegacyImageMigrationError.destinationStoreFailed(.keychain(.unexpectedPayload))
		}
	}

	private func deleteVerifiedSourceCard(for document: DocumentData) throws -> DocumentData {
		guard deleteSourceCard(document.id) else {
			throw LegacyImageMigrationError.sourceDeletionFailed(document: document)
		}
		return document
	}

	private func makeDocument(from card: CardData, kind: DocumentKind) -> DocumentData {
		let title = nonEmpty(card.description) ?? nonEmpty(card.name) ?? kind.rawValue
		var fields: [DocumentField] = []

		if let name = nonEmpty(card.name) {
			fields.append(DocumentField(kind: .holderName, value: name))
		}
		if let number = nonEmpty(card.number) {
			fields.append(DocumentField(kind: .documentNumber, value: number))
		}
		if let expiration = nonEmpty(card.expiration) {
			fields.append(DocumentField(kind: .expiryDate, value: expiration))
		}
		return DocumentData(
			id: card.id,
			title: title,
			kind: kind,
			fields: fields,
			isArchived: card.isArchived,
			sortIndex: card.sortIndex,
			isFavorite: card.isFavorite,
			palette: card.palette
		)
	}

	private func matchesExpectedMigrationMetadata(
		_ document: DocumentData,
		expected: DocumentData
	) -> Bool {
		document.id == expected.id
			&& document.title == expected.title
			&& document.kind == expected.kind
			&& document.fields.count == expected.fields.count
			&& zip(document.fields, expected.fields).allSatisfy { actual, expected in
				actual.kind == expected.kind
					&& actual.value == expected.value
					&& actual.label == expected.label
			}
			&& document.isArchived == expected.isArchived
			&& document.sortIndex == expected.sortIndex
			&& document.isFavorite == expected.isFavorite
			&& document.palette == expected.palette
	}

	private func nonEmpty(_ value: String) -> String? {
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}
}
