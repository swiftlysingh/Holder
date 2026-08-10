import Foundation
import XCTest
@testable import Holder

@MainActor
final class DocumentViewModelTests: XCTestCase {
	private var rootDirectory: URL!

	override func setUpWithError() throws {
		rootDirectory = FileManager.default.temporaryDirectory
			.appendingPathComponent("HolderDocumentViewModelTests-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		if let rootDirectory, FileManager.default.fileExists(atPath: rootDirectory.path) {
			try FileManager.default.removeItem(at: rootDirectory)
		}
		rootDirectory = nil
	}

	func testDocumentsAlwaysStartLockedEvenWhenCardAuthenticationIsDisabled() {
		let previousValue = UserSettings.shared.isAuthEnabled
		UserSettings.shared.isAuthEnabled = false
		defer { UserSettings.shared.isAuthEnabled = previousValue }

		let authenticator = MockCardAuthenticator()
		let model = makeModel(authenticator: authenticator)

		XCTAssertFalse(model.isAuthenticated)
		XCTAssertFalse(model.isAuthenticating)
		XCTAssertEqual(authenticator.evaluateCount, 0)
	}

	func testDocumentUnlockDoesNotBypassAuthenticationWhenCardAuthenticationIsDisabled() async {
		let previousValue = UserSettings.shared.isAuthEnabled
		UserSettings.shared.isAuthEnabled = false
		defer { UserSettings.shared.isAuthEnabled = previousValue }

		let authenticator = MockCardAuthenticator()
		let model = makeModel(authenticator: authenticator)

		model.unlock()

		XCTAssertTrue(model.isAuthenticating)
		XCTAssertEqual(authenticator.evaluateCount, 1)
		XCTAssertFalse(model.isAuthenticated)

		authenticator.completeOldest(success: true)
		await Task.yield()

		XCTAssertTrue(model.isAuthenticated)
		XCTAssertFalse(model.isAuthenticating)
	}

	func testFailedDocumentUnlockStaysLocked() async {
		let authenticator = MockCardAuthenticator()
		let model = makeModel(authenticator: authenticator)

		model.unlock()
		authenticator.completeOldest(success: false)
		await Task.yield()

		XCTAssertFalse(model.isAuthenticated)
		XCTAssertFalse(model.isAuthenticating)
	}

	func testDocumentLockInvalidatesStaleUnlockAndDoesNotReunlock() async {
		let authenticator = MockCardAuthenticator()
		let model = makeModel(authenticator: authenticator)

		model.unlock()
		XCTAssertTrue(model.isAuthenticating)

		model.lock()
		XCTAssertFalse(model.isAuthenticated)
		XCTAssertFalse(model.isAuthenticating)
		XCTAssertEqual(authenticator.invalidateCount, 1)

		authenticator.completeOldest(success: true)
		await Task.yield()

		XCTAssertFalse(model.isAuthenticated)
		XCTAssertFalse(model.isAuthenticating)
	}

	func testDocumentLockClearsLoadedPhotoBytes() async throws {
		let keychain = DocumentViewModelTestKeychain()
		let attachmentStore = DocumentAttachmentStore(
			rootDirectory: rootDirectory,
			keyService: "test.document-view-model.attachments.\(UUID().uuidString)",
			keychain: keychain
		)
		let store = DocumentDataStore(
			metadataService: "test.document-view-model.metadata.\(UUID().uuidString)",
			keychain: keychain,
			attachmentStore: attachmentStore,
			automaticallyLoads: false
		)
		let document = DocumentData(title: "Passport", kind: .passport)
		try store.add(document)
		let persistedDocument = try store.saveAttachment(
			Self.onePixelPNG,
			for: document,
			side: .front
		)
		XCTAssertNotNil(PlatformImage(data: Self.onePixelPNG))

		let authenticator = MockCardAuthenticator()
		let model = DocumentViewModel(
			document: persistedDocument,
			documentStore: store,
			authenticatorFactory: MockCardAuthenticatorFactory(authenticator)
		)

		XCTAssertNil(model.frontImage)
		model.unlock()
		authenticator.completeOldest(success: true)
		await Task.yield()

		XCTAssertNotNil(model.frontImage)
		model.lock()

		XCTAssertFalse(model.isAuthenticated)
		XCTAssertNil(model.frontImage)
		XCTAssertNil(model.backImage)
	}

	func testFailedDiscardBlocksResaveUntilSecureCleanupSucceeds() async throws {
		let keychain = DocumentViewModelTestKeychain()
		let attachmentStore = DocumentAttachmentStore(
			rootDirectory: rootDirectory,
			keyService: "test.document-view-model.attachments.\(UUID().uuidString)",
			keychain: keychain
		)
		let store = DocumentDataStore(
			metadataService: "test.document-view-model.metadata.\(UUID().uuidString)",
			keychain: keychain,
			attachmentStore: attachmentStore,
			automaticallyLoads: false
		)
		let authenticator = MockCardAuthenticator()
		let model = DocumentViewModel(
			document: DocumentData(title: "Passport", kind: .passport),
			documentStore: store,
			isEditing: true,
			isNewDocument: true,
			authenticatorFactory: MockCardAuthenticatorFactory(authenticator)
		)

		model.unlock()
		authenticator.completeOldest(success: true)
		await Task.yield()
		XCTAssertTrue(model.persist())

		keychain.shouldFailRemovals = true
		XCTAssertFalse(model.discardNewDocument())
		XCTAssertFalse(model.persist(), "A partial crypto-erasure must make this flow cancel-only")

		keychain.shouldFailRemovals = false
		XCTAssertTrue(model.discardNewDocument())
		XCTAssertNil(store.document(with: model.document.id))
	}

	func testLockDiscardsNewDocumentPlaintextAndRejectsStalePickerCompletion() async {
		let authenticator = MockCardAuthenticator()
		let keychain = DocumentViewModelTestKeychain()
		let attachmentStore = DocumentAttachmentStore(
			rootDirectory: rootDirectory,
			keyService: "test.document-view-model.attachments.\(UUID().uuidString)",
			keychain: keychain
		)
		let store = DocumentDataStore(
			metadataService: "test.document-view-model.metadata.\(UUID().uuidString)",
			keychain: keychain,
			attachmentStore: attachmentStore,
			automaticallyLoads: false
		)
		let model = DocumentViewModel(
			document: DocumentData(title: "Passport", kind: .passport),
			documentStore: store,
			isEditing: true,
			isNewDocument: true,
			authenticatorFactory: MockCardAuthenticatorFactory(authenticator)
		)

		model.unlock()
		authenticator.completeOldest(success: true)
		await Task.yield()
		let staleGeneration = model.authenticationGeneration
		model.saveAttachment(
			Self.onePixelPNG,
			side: .front,
			authenticationGeneration: staleGeneration
		)
		XCTAssertNotNil(model.frontImage)
		XCTAssertTrue(model.document.hasFrontImage)

		model.lock()
		XCTAssertNil(model.frontImage)
		XCTAssertFalse(model.document.hasFrontImage)

		model.unlock()
		authenticator.completeOldest(success: true)
		await Task.yield()
		model.saveAttachment(
			Self.onePixelPNG,
			side: .front,
			authenticationGeneration: staleGeneration
		)
		XCTAssertNil(model.frontImage)
		XCTAssertFalse(model.document.hasFrontImage)
	}

	private func makeModel(authenticator: MockCardAuthenticator) -> DocumentViewModel {
		let keychain = DocumentViewModelTestKeychain()
		let attachmentStore = DocumentAttachmentStore(
			rootDirectory: rootDirectory,
			keyService: "test.document-view-model.attachments.\(UUID().uuidString)",
			keychain: keychain
		)
		let store = DocumentDataStore(
			metadataService: "test.document-view-model.metadata.\(UUID().uuidString)",
			keychain: keychain,
			attachmentStore: attachmentStore,
			automaticallyLoads: false
		)
		return DocumentViewModel(
			document: DocumentData(title: "Passport", kind: .passport),
			documentStore: store,
			authenticatorFactory: MockCardAuthenticatorFactory(authenticator)
		)
	}

	private static let onePixelPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
}

private final class DocumentViewModelTestKeychain: DocumentKeychainClient {
	private struct Key: Hashable {
		let service: String
		let account: String
	}

	private var values: [Key: Data] = [:]
	var shouldFailRemovals = false

	func data(for account: String, service: String) throws -> Data? {
		values[Key(service: service, account: account)]
	}

	func allData(service: String) throws -> [Data] {
		values.compactMap { key, value in
			key.service == service ? value : nil
		}
	}

	func save(_ data: Data, for account: String, service: String, accessibility _: CFString) throws {
		values[Key(service: service, account: account)] = data
	}

	func remove(account: String, service: String) throws {
		if shouldFailRemovals {
			throw DocumentViewModelTestError.injectedRemovalFailure
		}
		values.removeValue(forKey: Key(service: service, account: account))
	}
}

private enum DocumentViewModelTestError: Error {
	case injectedRemovalFailure
}
