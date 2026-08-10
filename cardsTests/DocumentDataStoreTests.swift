import Foundation
import XCTest
@testable import Holder

final class DocumentDataStoreTests: XCTestCase {
	private var rootDirectory: URL!

	override func setUpWithError() throws {
		rootDirectory = FileManager.default.temporaryDirectory
			.appendingPathComponent("HolderDocumentDataStoreTests-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		if FileManager.default.fileExists(atPath: rootDirectory.path) {
			try FileManager.default.removeItem(at: rootDirectory)
		}
	}

	func testDocumentDataDecodesMissingPresentationAndAttachmentFields() throws {
		let id = UUID()
		let data = try JSONSerialization.data(withJSONObject: [
			"id": id.uuidString,
			"title": "Driving licence",
			"kind": DocumentKind.drivingLicence.rawValue
		])

		let document = try JSONDecoder().decode(DocumentData.self, from: data)

		XCTAssertEqual(document.id, id)
		XCTAssertEqual(document.kind, .drivingLicence)
		XCTAssertEqual(document.fields, [])
		XCTAssertFalse(document.hasFrontImage)
		XCTAssertFalse(document.hasBackImage)
		XCTAssertFalse(document.isArchived)
		XCTAssertNil(document.sortIndex)
		XCTAssertFalse(document.isFavorite)
		XCTAssertNil(document.palette)
	}

	func testDocumentDeckMetadataRoundTripsWithLegacySafeDefaults() throws {
		let document = DocumentData(
			id: UUID(),
			title: "Passport",
			kind: .passport,
			sortIndex: 3,
			isFavorite: true,
			palette: .forest
		)

		let decoded = try JSONDecoder().decode(DocumentData.self, from: JSONEncoder().encode(document))

		XCTAssertEqual(decoded.sortIndex, 3)
		XCTAssertTrue(decoded.isFavorite)
		XCTAssertEqual(decoded.palette, .forest)
		XCTAssertEqual(decoded.title, "Passport")
	}

	func testDocumentStoreOrdersFavoritesThenManualIndexThenStableLegacyID() throws {
		let keychain = InMemoryDocumentKeychain()
		let store = DocumentDataStore(
			metadataService: "test.metadata.\(UUID().uuidString)",
			keychain: keychain,
			automaticallyLoads: false
		)
		let firstLegacy = DocumentData(
			id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
			title: "Zulu legacy",
			kind: .passport
		)
		let secondLegacy = DocumentData(
			id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
			title: "Alpha legacy",
			kind: .passport
		)
		let manual = DocumentData(
			id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
			title: "Manual",
			kind: .passport,
			sortIndex: 2
		)
		let favorite = DocumentData(
			id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
			title: "Favorite",
			kind: .passport,
			sortIndex: 99,
			isFavorite: true
		)

		try store.add(secondLegacy)
		try store.add(manual)
		try store.add(favorite)
		try store.add(firstLegacy)

		XCTAssertEqual(
			store.documents.map(\.id),
			[favorite.id, manual.id, firstLegacy.id, secondLegacy.id]
		)
	}

	func testDocumentMetadataRoundTripsInDedicatedStore() throws {
		let keychain = InMemoryDocumentKeychain()
		let metadataService = "test.metadata.\(UUID().uuidString)"
		let attachmentService = "test.attachments.\(UUID().uuidString)"
		let attachmentStore = DocumentAttachmentStore(
			rootDirectory: rootDirectory,
			keyService: attachmentService,
			keychain: keychain
		)
		let store = DocumentDataStore(
			metadataService: metadataService,
			keychain: keychain,
			attachmentStore: attachmentStore,
			automaticallyLoads: false
		)
		let document = makeDocument()

		try store.add(document)

		let reloaded = DocumentDataStore(
			metadataService: metadataService,
			keychain: keychain,
			attachmentStore: attachmentStore,
			automaticallyLoads: false
		)
		switch reloaded.loadDocuments() {
		case .success(let documents):
			XCTAssertEqual(documents, [document])
		case .failure(let error):
			XCTFail("Unexpected metadata load failure: \(error)")
		}
		XCTAssertEqual(keychain.services, Set([metadataService]))
	}

	func testAttachmentsAreEncryptedAtRestAndRoundTrip() throws {
		let keychain = InMemoryDocumentKeychain()
		let attachmentStore = DocumentAttachmentStore(
			rootDirectory: rootDirectory,
			keyService: "test.attachments.\(UUID().uuidString)",
			keychain: keychain
		)
		let documentID = UUID()
		let plainText = Data("front image bytes".utf8)

		try attachmentStore.save(plainText, for: documentID, side: .front)
		let url = try attachmentStore.attachmentURL(for: documentID, side: .front)
		let encrypted = try Data(contentsOf: url)

		XCTAssertNotEqual(encrypted, plainText)
		XCTAssertEqual(try attachmentStore.load(for: documentID, side: .front), plainText)
		XCTAssertEqual(url.lastPathComponent, "front.holder")
		#if os(iOS)
		let fileValues = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
		let directoryValues = try url.deletingLastPathComponent().resourceValues(forKeys: [.isExcludedFromBackupKey])
		XCTAssertEqual(fileValues.isExcludedFromBackup, true)
		XCTAssertEqual(directoryValues.isExcludedFromBackup, true)
		#endif
	}

	func testAttachmentURLsStayInsideInjectedRoot() throws {
		let safeRoot = rootDirectory.appendingPathComponent("safe/../attachment-root", isDirectory: true)
		let attachmentStore = DocumentAttachmentStore(
			rootDirectory: safeRoot,
			keyService: "test.attachments.\(UUID().uuidString)",
			keychain: InMemoryDocumentKeychain()
		)

		let url = try attachmentStore.attachmentURL(for: UUID(), side: .back)
		let normalizedRoot = safeRoot.standardizedFileURL.path + "/"

		XCTAssertTrue(url.standardizedFileURL.path.hasPrefix(normalizedRoot))
		XCTAssertEqual(url.lastPathComponent, "back.holder")
		XCTAssertFalse(url.pathComponents.contains(".."))
	}

	func testDeletingEncryptionKeyMakesExistingCiphertextUnreadable() throws {
		let keychain = InMemoryDocumentKeychain()
		let attachmentStore = DocumentAttachmentStore(
			rootDirectory: rootDirectory,
			keyService: "test.attachments.\(UUID().uuidString)",
			keychain: keychain
		)
		let documentID = UUID()

		try attachmentStore.save(Data("sensitive".utf8), for: documentID, side: .front)
		let url = try attachmentStore.attachmentURL(for: documentID, side: .front)
		XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

		try attachmentStore.deleteKey(for: documentID)

		XCTAssertNil(try attachmentStore.load(for: documentID, side: .front))
		XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
	}

	func testDocumentDeletionOrdersCryptoErasureBeforeMetadataAndIsRetrySafe() throws {
		let keychain = InMemoryDocumentKeychain()
		let metadataService = "test.metadata.\(UUID().uuidString)"
		let attachmentService = "test.attachments.\(UUID().uuidString)"
		let attachmentStore = DocumentAttachmentStore(
			rootDirectory: rootDirectory,
			keyService: attachmentService,
			keychain: keychain
		)
		let store = DocumentDataStore(
			metadataService: metadataService,
			keychain: keychain,
			attachmentStore: attachmentStore,
			automaticallyLoads: false
		)
		let document = makeDocument()
		try store.add(document)
		_ = try store.saveAttachment(Data("front".utf8), for: document, side: .front)
		_ = try store.saveAttachment(Data("back".utf8), for: document, side: .back)
		let frontURL = try attachmentStore.attachmentURL(for: document.id, side: .front)
		let backURL = try attachmentStore.attachmentURL(for: document.id, side: .back)
		keychain.operations.removeAll()

		try store.delete(document)

		XCTAssertFalse(FileManager.default.fileExists(atPath: frontURL.path))
		XCTAssertFalse(FileManager.default.fileExists(atPath: backURL.path))
		XCTAssertNil(store.document(with: document.id))
		XCTAssertEqual(
			Array(keychain.operations.suffix(2)),
			["remove:\(attachmentService):\(document.id.uuidString)", "remove:\(metadataService):\(document.id.uuidString)"]
		)

		// Both Keychain deletes accept an already-absent item; this makes cleanup
		// retryable after an interrupted application termination.
		try store.delete(document)
	}

	func testAttachmentCreateRollsBackCiphertextWhenMetadataSaveFails() throws {
		let keychain = InMemoryDocumentKeychain()
		let metadataService = "test.metadata.\(UUID().uuidString)"
		let attachmentService = "test.attachments.\(UUID().uuidString)"
		let attachmentStore = DocumentAttachmentStore(
			rootDirectory: rootDirectory,
			keyService: attachmentService,
			keychain: keychain
		)
		let store = DocumentDataStore(
			metadataService: metadataService,
			keychain: keychain,
			attachmentStore: attachmentStore,
			automaticallyLoads: false
		)
		let document = makeDocument()
		try store.add(document)
		keychain.failingSaveServices.insert(metadataService)

		XCTAssertThrowsError(
			try store.saveAttachment(Data("new front".utf8), for: document, side: .front)
		)

		XCTAssertNil(try attachmentStore.load(for: document.id, side: .front))
		XCTAssertNil(try keychain.data(for: document.id.uuidString, service: attachmentService))
		XCTAssertFalse(try XCTUnwrap(store.document(with: document.id)).hasFrontImage)
	}

	func testFailedDocumentFavoriteSaveDoesNotMutateInMemoryState() throws {
		let keychain = InMemoryDocumentKeychain()
		let metadataService = "test.metadata.\(UUID().uuidString)"
		let store = DocumentDataStore(
			metadataService: metadataService,
			keychain: keychain,
			automaticallyLoads: false
		)
		let document = makeDocument()
		try store.add(document)
		keychain.failingSaveServices.insert(metadataService)

		XCTAssertThrowsError(try store.setFavorite(documentID: document.id, isFavorite: true))
		XCTAssertFalse(try XCTUnwrap(store.document(with: document.id)).isFavorite)
		XCTAssertNotNil(store.lastError)
	}

	func testFailedDocumentDeckReorderExposesOnlyPersistedPrefix() throws {
		let keychain = InMemoryDocumentKeychain()
		let metadataService = "test.metadata.\(UUID().uuidString)"
		let store = DocumentDataStore(
			metadataService: metadataService,
			keychain: keychain,
			automaticallyLoads: false
		)
		let first = DocumentData(title: "First", kind: .passport)
		let second = DocumentData(title: "Second", kind: .drivingLicence)
		try store.add(first)
		try store.add(second)
		keychain.saveAttemptCount = 0
		keychain.failOnSaveAttempt = 2

		var firstReordered = first
		firstReordered.sortIndex = 1
		var secondReordered = second
		secondReordered.sortIndex = 0

		XCTAssertThrowsError(try store.updateDeckOrder([firstReordered, secondReordered]))
		XCTAssertEqual(store.document(with: first.id)?.sortIndex, 1)
		XCTAssertNil(store.document(with: second.id)?.sortIndex)
		XCTAssertNotNil(store.lastError)

		let reloaded = DocumentDataStore(
			metadataService: metadataService,
			keychain: keychain,
			automaticallyLoads: false
		)
		_ = reloaded.loadDocuments()
		XCTAssertEqual(reloaded.document(with: first.id)?.sortIndex, 1)
		XCTAssertNil(reloaded.document(with: second.id)?.sortIndex)
	}

	func testAttachmentReplacementRestoresPreviousBytesWhenMetadataSaveFails() throws {
		let keychain = InMemoryDocumentKeychain()
		let metadataService = "test.metadata.\(UUID().uuidString)"
		let attachmentStore = DocumentAttachmentStore(
			rootDirectory: rootDirectory,
			keyService: "test.attachments.\(UUID().uuidString)",
			keychain: keychain
		)
		let store = DocumentDataStore(
			metadataService: metadataService,
			keychain: keychain,
			attachmentStore: attachmentStore,
			automaticallyLoads: false
		)
		let document = makeDocument()
		let previous = Data("previous front".utf8)
		try store.add(document)
		let persisted = try store.saveAttachment(previous, for: document, side: .front)
		keychain.failingSaveServices.insert(metadataService)

		XCTAssertThrowsError(
			try store.saveAttachment(Data("replacement".utf8), for: persisted, side: .front)
		)

		XCTAssertEqual(try attachmentStore.load(for: document.id, side: .front), previous)
		XCTAssertTrue(try XCTUnwrap(store.document(with: document.id)).hasFrontImage)
	}

	func testAttachmentDeleteRestoresPreviousBytesWhenMetadataSaveFails() throws {
		let keychain = InMemoryDocumentKeychain()
		let metadataService = "test.metadata.\(UUID().uuidString)"
		let attachmentStore = DocumentAttachmentStore(
			rootDirectory: rootDirectory,
			keyService: "test.attachments.\(UUID().uuidString)",
			keychain: keychain
		)
		let store = DocumentDataStore(
			metadataService: metadataService,
			keychain: keychain,
			attachmentStore: attachmentStore,
			automaticallyLoads: false
		)
		let document = makeDocument()
		let previous = Data("previous front".utf8)
		try store.add(document)
		let persisted = try store.saveAttachment(previous, for: document, side: .front)
		keychain.failingSaveServices.insert(metadataService)

		XCTAssertThrowsError(try store.deleteAttachment(for: persisted, side: .front))

		XCTAssertEqual(try attachmentStore.load(for: document.id, side: .front), previous)
		XCTAssertTrue(try XCTUnwrap(store.document(with: document.id)).hasFrontImage)
	}

	private func makeDocument() -> DocumentData {
		DocumentData(
			title: "Driving licence",
			kind: .drivingLicence,
			fields: [
				DocumentField(kind: .documentNumber, value: "S1234 56789 01", label: "Licence number"),
				DocumentField(kind: .expiryDate, value: "14 Mar 2031"),
				DocumentField(kind: .documentClass, value: "B, BE")
			],
			palette: .emerald
		)
	}
}

private final class InMemoryDocumentKeychain: DocumentKeychainClient {
	private struct Key: Hashable {
		let service: String
		let account: String
	}

	private var values: [Key: Data] = [:]
	private(set) var services: Set<String> = []
	var operations: [String] = []
	var failingSaveServices: Set<String> = []
	var saveAttemptCount = 0
	var failOnSaveAttempt: Int?

	func data(for account: String, service: String) throws -> Data? {
		services.insert(service)
		return values[Key(service: service, account: account)]
	}

	func allData(service: String) throws -> [Data] {
		services.insert(service)
		return values.compactMap { key, value in
			key.service == service ? value : nil
		}
	}

	func save(_ data: Data, for account: String, service: String, accessibility _: CFString) throws {
		services.insert(service)
		saveAttemptCount += 1
		if failingSaveServices.contains(service) || failOnSaveAttempt == saveAttemptCount {
			throw DocumentKeychainError.unexpectedStatus(errSecInteractionNotAllowed)
		}
		values[Key(service: service, account: account)] = data
		operations.append("save:\(service):\(account)")
	}

	func remove(account: String, service: String) throws {
		services.insert(service)
		values.removeValue(forKey: Key(service: service, account: account))
		operations.append("remove:\(service):\(account)")
	}
}
