//
//  DocumentDataStore.swift
//  Holder
//
//  Separate metadata persistence for photo-first documents. This store never
//  reads or writes legacy `Other Card` data; migration requires an explicit,
//  user-confirmed document creation flow.
//

import Foundation
import Observation
import Security

enum DocumentDataStoreError: Error, LocalizedError, Equatable {
	case keychain(DocumentKeychainError)
	case encodingFailed
	case decodingFailed
	case attachment(DocumentAttachmentStoreError)
	case invalidDeckOrder
	case documentNotFound

	var errorDescription: String? {
		switch self {
		case .keychain:
			return "The document metadata could not be stored securely."
		case .encodingFailed:
			return "The document metadata could not be prepared for secure storage."
		case .decodingFailed:
			return "The stored document metadata could not be read."
		case .attachment(let error):
			return error.errorDescription
		case .invalidDeckOrder:
			return "Holder could not save that deck order."
		case .documentNotFound:
			return "That document is no longer available."
		}
	}
}

@Observable
final class DocumentDataStore {
	private static let metadataServiceSuffix = ".documents.v1"

	private let metadataService: String
	private let keychain: DocumentKeychainClient
	let attachmentStore: DocumentAttachmentStore

	private(set) var documents: [DocumentData] = []
	private(set) var archivedDocuments: [DocumentData] = []
	private(set) var lastError: DocumentDataStoreError?

	init(
		metadataService: String? = nil,
		keychain: DocumentKeychainClient = SecurityDocumentKeychainClient(),
		attachmentStore: DocumentAttachmentStore? = nil,
		automaticallyLoads: Bool = true
	) {
		self.metadataService = metadataService ?? Self.defaultMetadataService
		self.keychain = keychain
		self.attachmentStore = attachmentStore ?? DocumentAttachmentStore()

		if automaticallyLoads {
			_ = loadDocuments()
		}
	}

	var allDocuments: [DocumentData] {
		documents + archivedDocuments
	}

	@discardableResult
	func loadDocuments() -> Result<[DocumentData], DocumentDataStoreError> {
		do {
			let documents = try keychain.allData(service: metadataService).map(decodeDocument)
			commit(documents)
			lastError = nil
			return .success(documents)
		} catch let error as DocumentDataStoreError {
			lastError = error
			return .failure(error)
		} catch let error as DocumentKeychainError {
			let storeError = DocumentDataStoreError.keychain(error)
			lastError = storeError
			return .failure(storeError)
		} catch {
			lastError = .decodingFailed
			return .failure(.decodingFailed)
		}
	}

	func document(with id: UUID) -> DocumentData? {
		documents.first(where: { $0.id == id }) ?? archivedDocuments.first(where: { $0.id == id })
	}

	func add(_ document: DocumentData) throws {
		try save(document)
	}

	func update(_ document: DocumentData) throws {
		try save(document)
	}

	/// Persists the metadata before exposing the favorite change to SwiftUI.
	func setFavorite(documentID: UUID, isFavorite: Bool) throws {
		guard var document = document(with: documentID) else {
			lastError = .documentNotFound
			throw DocumentDataStoreError.documentNotFound
		}
		document.isFavorite = isFavorite
		try save(document)
	}

	/// Persists an externally ordered subset of document metadata. The combined
	/// card/document deck owns the actual integer positions; this store only
	/// writes document records. If a later Keychain write fails, the successfully
	/// saved prefix is committed to memory so the deck never displays a state
	/// that differs from durable storage.
	func updateDeckOrder(_ orderedDocuments: [DocumentData]) throws {
		let currentIDs = Set(allDocuments.map(\.id))
		let orderedIDs = orderedDocuments.map(\.id)
		guard orderedIDs.count == Set(orderedIDs).count,
			orderedIDs.allSatisfy({ currentIDs.contains($0) }) else {
			lastError = .invalidDeckOrder
			throw DocumentDataStoreError.invalidDeckOrder
		}

		var persistedDocuments: [DocumentData] = []
		do {
			for document in orderedDocuments {
				try persist(document)
				persistedDocuments.append(document)
			}
		} catch {
			commitPersistedDocuments(persistedDocuments)
			let storeError = normalizedStoreError(error)
			lastError = storeError
			throw storeError
		}

		commitPersistedDocuments(persistedDocuments)
		lastError = nil
	}

	func archive(_ document: DocumentData) throws {
		var archived = document
		archived.isArchived = true
		try save(archived)
	}

	func unarchive(_ document: DocumentData) throws {
		var unarchived = document
		unarchived.isArchived = false
		try save(unarchived)
	}

	/// Performs crypto-erasure before removing any file or metadata reference:
	/// key -> encrypted front/back files -> Keychain metadata. Each phase is
	/// intentionally allowed to fail so a caller can retain an actionable error.
	func delete(_ document: DocumentData) throws {
		do {
			try attachmentStore.deleteKey(for: document.id)
			try attachmentStore.deleteAttachments(for: document.id)
			try keychain.remove(account: document.id.uuidString, service: metadataService)
		} catch let error as DocumentAttachmentStoreError {
			let storeError = DocumentDataStoreError.attachment(error)
			lastError = storeError
			throw storeError
		} catch let error as DocumentKeychainError {
			let storeError = DocumentDataStoreError.keychain(error)
			lastError = storeError
			throw storeError
		} catch {
			lastError = .keychain(.unexpectedPayload)
			throw DocumentDataStoreError.keychain(.unexpectedPayload)
		}

		documents.removeAll { $0.id == document.id }
		archivedDocuments.removeAll { $0.id == document.id }
		lastError = nil
	}

	/// Saves encrypted bytes first, then marks that slot present in metadata.
	/// A metadata failure restores the previous encrypted attachment state.
	/// UI code should use this instead of changing `hasFrontImage`/`hasBackImage`
	/// directly so the deck state remains honest after a persistence failure.
	@discardableResult
	func saveAttachment(
		_ data: Data,
		for document: DocumentData,
		side: DocumentAttachmentSide
	) throws -> DocumentData {
		let previousCiphertext = try encryptedAttachmentData(for: document.id, side: side)
		let createdKey: Bool
		do {
			createdKey = try attachmentStore.save(data, for: document.id, side: side)
		} catch let error as DocumentAttachmentStoreError {
			throw recordAttachmentError(error)
		}

		var updated = self.document(with: document.id) ?? document
		updated.setHasImage(true, for: side)
		do {
			try save(updated)
		} catch {
			let metadataError = normalizedStoreError(error)
			var rollbackError: DocumentAttachmentStoreError?
			do {
				try attachmentStore.restoreEncryptedAttachmentData(
					previousCiphertext,
					for: document.id,
					side: side
				)
			} catch let error as DocumentAttachmentStoreError {
				rollbackError = error
			}
			if createdKey {
				do {
					try attachmentStore.deleteKey(for: document.id)
				} catch let error as DocumentAttachmentStoreError {
					rollbackError = rollbackError ?? error
				}
			}
			if let rollbackError {
				throw recordAttachmentError(rollbackError)
			}
			lastError = metadataError
			throw metadataError
		}
		return updated
	}

	@discardableResult
	func deleteAttachment(
		for document: DocumentData,
		side: DocumentAttachmentSide
	) throws -> DocumentData {
		let previousCiphertext = try encryptedAttachmentData(for: document.id, side: side)
		do {
			try attachmentStore.deleteAttachment(for: document.id, side: side)
		} catch let error as DocumentAttachmentStoreError {
			throw recordAttachmentError(error)
		}

		var updated = self.document(with: document.id) ?? document
		updated.setHasImage(false, for: side)
		do {
			try save(updated)
		} catch {
			let metadataError = normalizedStoreError(error)
			if let previousCiphertext {
				do {
					try attachmentStore.restoreEncryptedAttachmentData(
						previousCiphertext,
						for: document.id,
						side: side
					)
				} catch let rollbackError as DocumentAttachmentStoreError {
					throw recordAttachmentError(rollbackError)
				}
			}
			lastError = metadataError
			throw metadataError
		}
		return updated
	}

	func attachmentData(for documentID: UUID, side: DocumentAttachmentSide) throws -> Data? {
		try loadAttachmentData(for: documentID, side: side)
	}

	private func loadAttachmentData(
		for documentID: UUID,
		side: DocumentAttachmentSide
	) throws -> Data? {
		do {
			return try attachmentStore.load(for: documentID, side: side)
		} catch let error as DocumentAttachmentStoreError {
			throw recordAttachmentError(error)
		}
	}

	private func encryptedAttachmentData(
		for documentID: UUID,
		side: DocumentAttachmentSide
	) throws -> Data? {
		do {
			return try attachmentStore.encryptedAttachmentData(for: documentID, side: side)
		} catch let error as DocumentAttachmentStoreError {
			throw recordAttachmentError(error)
		}
	}

	private func recordAttachmentError(_ error: DocumentAttachmentStoreError) -> DocumentDataStoreError {
		let storeError = DocumentDataStoreError.attachment(error)
		lastError = storeError
		return storeError
	}

	private func normalizedStoreError(_ error: Error) -> DocumentDataStoreError {
		if let error = error as? DocumentDataStoreError {
			return error
		}
		return .keychain(.unexpectedPayload)
	}

	private func save(_ document: DocumentData) throws {
		try persist(document)
		commitPersistedDocuments([document])
		lastError = nil
	}

	private func persist(_ document: DocumentData) throws {
		let data: Data
		do {
			data = try JSONEncoder().encode(document)
		} catch {
			lastError = .encodingFailed
			throw DocumentDataStoreError.encodingFailed
		}

		do {
			try keychain.save(
				data,
				for: document.id.uuidString,
				service: metadataService,
				accessibility: Self.deviceOnlyAccessibility
			)
		} catch let error as DocumentKeychainError {
			let storeError = DocumentDataStoreError.keychain(error)
			lastError = storeError
			throw storeError
		} catch {
			lastError = .keychain(.unexpectedPayload)
			throw DocumentDataStoreError.keychain(.unexpectedPayload)
		}

	}

	private func commitPersistedDocuments(_ replacements: [DocumentData]) {
		guard !replacements.isEmpty else { return }
		var current = allDocuments
		for replacement in replacements {
			current.removeAll { $0.id == replacement.id }
			current.append(replacement)
		}
		commit(current)
	}

	private func decodeDocument(_ data: Data) throws -> DocumentData {
		do {
			return try JSONDecoder().decode(DocumentData.self, from: data)
		} catch {
			throw DocumentDataStoreError.decodingFailed
		}
	}

	private func commit(_ values: [DocumentData]) {
		documents = Self.deckOrdered(values.filter { !$0.isArchived })
		archivedDocuments = Self.deckOrdered(values.filter(\.isArchived))
	}

	/// Match cards' ordering semantics without leaking document fields into the
	/// sort. Legacy records are stable by UUID until they receive a manual order.
	private static func deckOrdered(_ documents: [DocumentData]) -> [DocumentData] {
		documents.sorted { lhs, rhs in
			if lhs.isFavorite != rhs.isFavorite {
				return lhs.isFavorite
			}
			let lhsIndex = lhs.sortIndex ?? Int.max
			let rhsIndex = rhs.sortIndex ?? Int.max
			if lhsIndex != rhsIndex {
				return lhsIndex < rhsIndex
			}
			return lhs.id.uuidString < rhs.id.uuidString
		}
	}

	private static var defaultMetadataService: String {
		"\(Bundle.main.bundleIdentifier ?? "com.swiftlysingh.cards")\(metadataServiceSuffix)"
	}

	private static var deviceOnlyAccessibility: CFString {
		#if os(iOS) || os(visionOS) || targetEnvironment(macCatalyst)
			kSecAttrAccessibleWhenUnlockedThisDeviceOnly
		#else
			kSecAttrAccessibleWhenUnlocked
		#endif
	}
}
