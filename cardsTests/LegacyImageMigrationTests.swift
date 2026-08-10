import Foundation
import XCTest
@testable import Holder

@MainActor
final class LegacyImageMigrationTests: XCTestCase {
	private var rootDirectory: URL!

	override func setUpWithError() throws {
		rootDirectory = FileManager.default.temporaryDirectory
			.appendingPathComponent("HolderLegacyImageMigrationTests-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		if FileManager.default.fileExists(atPath: rootDirectory.path) {
			try FileManager.default.removeItem(at: rootDirectory)
		}
	}

	func testMigrationPreservesUUIDAndUsefulFieldsAfterEncryptedReadBack() throws {
		let keychain = InMemoryMigrationKeychain()
		let attachmentStore = makeAttachmentStore(keychain: keychain)
		let documentStore = makeDocumentStore(keychain: keychain, attachmentStore: attachmentStore)
		let card = makeLegacyCard(isArchived: true)
		let sourceData = Data("legacy-image-source".utf8)
		var deletedIDs: [UUID] = []
		let service = LegacyImageMigrationService(
			documentStore: documentStore,
			loadSourceImageData: { _ in sourceData },
			deleteSourceCard: {
				deletedIDs.append($0)
				return true
			}
		)

		let document = try service.migrate(card, as: .passport)

		XCTAssertEqual(document.id, card.id)
		XCTAssertEqual(document.title, "Passport")
		XCTAssertEqual(document.kind, .passport)
		XCTAssertTrue(document.isArchived)
		XCTAssertEqual(document.sortIndex, 4)
		XCTAssertTrue(document.isFavorite)
		XCTAssertEqual(document.palette, .forest)
		XCTAssertEqual(document.fields.map(\.kind), [.holderName, .documentNumber, .expiryDate])
		XCTAssertEqual(document.fields.map(\.value), ["Ada Lovelace", card.number, "2031-03-14"])
		XCTAssertEqual(document.fields.map(\.label), [nil, nil, nil])
		XCTAssertTrue(document.hasFrontImage)
		XCTAssertNotEqual(
			try attachmentStore.encryptedAttachmentData(for: card.id, side: .front),
			sourceData
		)
		XCTAssertEqual(try documentStore.attachmentData(for: card.id, side: .front), sourceData)
		XCTAssertEqual(deletedIDs, [card.id])
	}

	func testSourceDeletionRunsOnlyAfterTheFrontAttachmentCanBeReadBack() throws {
		let keychain = InMemoryMigrationKeychain()
		let attachmentStore = makeAttachmentStore(keychain: keychain)
		let documentStore = makeDocumentStore(keychain: keychain, attachmentStore: attachmentStore)
		let card = makeLegacyCard()
		let sourceData = Data("must-verify-before-delete".utf8)
		var sourceDeletionSawVerifiedAttachment = false
		let service = LegacyImageMigrationService(
			documentStore: documentStore,
			loadSourceImageData: { _ in sourceData },
			deleteSourceCard: { id in
				if let attachment = try? documentStore.attachmentData(for: id, side: .front) {
					sourceDeletionSawVerifiedAttachment = id == card.id && attachment == sourceData
				}
				return true
			}
		)

		_ = try service.migrate(card, as: .drivingLicence)

		XCTAssertTrue(sourceDeletionSawVerifiedAttachment)
	}

	func testDestinationFailureLeavesSourceUntouched() throws {
		let keychain = InMemoryMigrationKeychain()
		let metadataService = "test.migration.metadata.\(UUID().uuidString)"
		keychain.failingSaveServices.insert(metadataService)
		let documentStore = DocumentDataStore(
			metadataService: metadataService,
			keychain: keychain,
			attachmentStore: makeAttachmentStore(keychain: keychain),
			automaticallyLoads: false
		)
		let card = makeLegacyCard()
		var sourceDeleteCount = 0
		let service = LegacyImageMigrationService(
			documentStore: documentStore,
			loadSourceImageData: { _ in Data("source".utf8) },
			deleteSourceCard: { _ in
				sourceDeleteCount += 1
				return true
			}
		)

		XCTAssertThrowsError(try service.migrate(card, as: .nationalID)) { error in
			XCTAssertEqual(
				error as? LegacyImageMigrationError,
				.destinationStoreFailed(.keychain(.unexpectedPayload))
			)
		}
		XCTAssertEqual(sourceDeleteCount, 0)
		XCTAssertNil(documentStore.document(with: card.id))
	}

	func testOnlyExplicitOtherCardsAreEligibleForMigration() throws {
		let keychain = InMemoryMigrationKeychain()
		let documentStore = makeDocumentStore(
			keychain: keychain,
			attachmentStore: makeAttachmentStore(keychain: keychain)
		)
		var sourceLoadCount = 0
		var sourceDeleteCount = 0
		let service = LegacyImageMigrationService(
			documentStore: documentStore,
			loadSourceImageData: { _ in
				sourceLoadCount += 1
				return Data("source".utf8)
			},
			deleteSourceCard: { _ in
				sourceDeleteCount += 1
				return true
			}
		)
		var card = makeLegacyCard()
		card.type = .creditCard

		XCTAssertThrowsError(try service.migrate(card, as: .passport)) { error in
			XCTAssertEqual(error as? LegacyImageMigrationError, .sourceIsNotOtherCard)
		}
		XCTAssertEqual(sourceLoadCount, 0)
		XCTAssertEqual(sourceDeleteCount, 0)
	}

	func testSourceDeleteFailureReturnsRetryableErrorAndKeepsVerifiedDocument() throws {
		let keychain = InMemoryMigrationKeychain()
		let attachmentStore = makeAttachmentStore(keychain: keychain)
		let documentStore = makeDocumentStore(keychain: keychain, attachmentStore: attachmentStore)
		let card = makeLegacyCard()
		let sourceData = Data("encrypted-before-delete-failure".utf8)
		let service = LegacyImageMigrationService(
			documentStore: documentStore,
			loadSourceImageData: { _ in sourceData },
			deleteSourceCard: { _ in false }
		)

		XCTAssertThrowsError(try service.migrate(card, as: .residencePermit)) { error in
			guard let migrationError = error as? LegacyImageMigrationError else {
				return XCTFail("Expected a structured migration error")
			}
			XCTAssertTrue(migrationError.isRetryable)
			XCTAssertEqual(migrationError.recoveredDocument?.id, card.id)
		}

		let document = try XCTUnwrap(documentStore.document(with: card.id))
		XCTAssertTrue(document.hasFrontImage)
		XCTAssertEqual(try documentStore.attachmentData(for: card.id, side: .front), sourceData)
	}

	func testRetryReusesVerifiedSameIDDocumentWithoutSourceBytes() throws {
		let keychain = InMemoryMigrationKeychain()
		let attachmentStore = makeAttachmentStore(keychain: keychain)
		let documentStore = makeDocumentStore(keychain: keychain, attachmentStore: attachmentStore)
		let card = makeLegacyCard()
		let sourceData = Data("retryable-legacy-image".utf8)
		let firstService = LegacyImageMigrationService(
			documentStore: documentStore,
			loadSourceImageData: { _ in sourceData },
			deleteSourceCard: { _ in false }
		)

		XCTAssertThrowsError(try firstService.migrate(card, as: .insurance))
		let ciphertextBeforeRetry = try XCTUnwrap(
			attachmentStore.encryptedAttachmentData(for: card.id, side: .front)
		)
		var deletedIDs: [UUID] = []
		let retryService = LegacyImageMigrationService(
			documentStore: documentStore,
			// Models a partial legacy deletion: the old iCloud file has already gone,
			// but its card metadata needs a retry. The verified destination is retained.
			loadSourceImageData: { _ in nil },
			deleteSourceCard: {
				deletedIDs.append($0)
				return true
			}
		)

		let document = try retryService.migrate(card, as: .insurance)

		XCTAssertEqual(document.id, card.id)
		XCTAssertEqual(deletedIDs, [card.id])
		XCTAssertEqual(
			try attachmentStore.encryptedAttachmentData(for: card.id, side: .front),
			ciphertextBeforeRetry,
			"A verified retry must not rewrite the encrypted attachment."
		)
	}

	private func makeDocumentStore(
		keychain: InMemoryMigrationKeychain,
		attachmentStore: DocumentAttachmentStore
	) -> DocumentDataStore {
		DocumentDataStore(
			metadataService: "test.migration.metadata.\(UUID().uuidString)",
			keychain: keychain,
			attachmentStore: attachmentStore,
			automaticallyLoads: false
		)
	}

	private func makeAttachmentStore(keychain: InMemoryMigrationKeychain) -> DocumentAttachmentStore {
		DocumentAttachmentStore(
			rootDirectory: rootDirectory,
			keyService: "test.migration.attachments.\(UUID().uuidString)",
			keychain: keychain
		)
	}

	private func makeLegacyCard(isArchived: Bool = false) -> CardData {
		CardData(
			id: UUID(),
			number: "7788990011",
			cvv: "legacy-code",
			expiration: "2031-03-14",
			name: "  Ada Lovelace  ",
			description: "  Passport  ",
			type: .otherCard,
			network: .other,
			isArchived: isArchived,
			sortIndex: 4,
			isFavorite: true,
			palette: .forest,
			hasLegacyImage: true
		)
	}
}

private final class InMemoryMigrationKeychain: DocumentKeychainClient {
	private struct Key: Hashable {
		let service: String
		let account: String
	}

	private var values: [Key: Data] = [:]
	var failingSaveServices: Set<String> = []

	func data(for account: String, service: String) throws -> Data? {
		values[Key(service: service, account: account)]
	}

	func allData(service: String) throws -> [Data] {
		values.compactMap { key, value in
			key.service == service ? value : nil
		}
	}

	func save(_ data: Data, for account: String, service: String, accessibility _: CFString) throws {
		guard !failingSaveServices.contains(service) else {
			throw DocumentKeychainError.unexpectedPayload
		}
		values[Key(service: service, account: account)] = data
	}

	func remove(account: String, service: String) throws {
		values.removeValue(forKey: Key(service: service, account: account))
	}
}
