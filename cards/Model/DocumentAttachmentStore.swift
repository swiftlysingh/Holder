//
//  DocumentAttachmentStore.swift
//  Holder
//
//  Device-local encrypted document attachment storage.
//

import CryptoKit
import Foundation
import Security

enum DocumentKeychainError: Error, LocalizedError, Equatable {
	case unexpectedStatus(OSStatus)
	case unexpectedPayload

	var errorDescription: String? {
		switch self {
		case .unexpectedStatus:
			return "The secure storage operation could not be completed."
		case .unexpectedPayload:
			return "The secure storage returned an unexpected value."
		}
	}
}

/// Kept deliberately small so document storage can use an isolated Keychain
/// namespace in production and deterministic in-memory storage in unit tests.
protocol DocumentKeychainClient {
	func data(for account: String, service: String) throws -> Data?
	func allData(service: String) throws -> [Data]
	func save(_ data: Data, for account: String, service: String, accessibility: CFString) throws
	func remove(account: String, service: String) throws
}

struct SecurityDocumentKeychainClient: DocumentKeychainClient {
	func data(for account: String, service: String) throws -> Data? {
		var query = baseQuery(service: service, account: account)
		query[kSecReturnData as String] = kCFBooleanTrue!
		query[kSecMatchLimit as String] = kSecMatchLimitOne

		var result: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &result)
		switch status {
		case errSecSuccess:
			guard let data = result as? Data else {
				throw DocumentKeychainError.unexpectedPayload
			}
			return data
		case errSecItemNotFound:
			return nil
		default:
			throw DocumentKeychainError.unexpectedStatus(status)
		}
	}

	func allData(service: String) throws -> [Data] {
		var query = baseQuery(service: service)
		query[kSecReturnData as String] = kCFBooleanTrue!
		query[kSecMatchLimit as String] = kSecMatchLimitAll

		var result: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &result)
		switch status {
		case errSecSuccess:
			if let data = result as? Data {
				return [data]
			}
			guard let data = result as? [Data] else {
				throw DocumentKeychainError.unexpectedPayload
			}
			return data
		case errSecItemNotFound:
			return []
		default:
			throw DocumentKeychainError.unexpectedStatus(status)
		}
	}

	func save(_ data: Data, for account: String, service: String, accessibility: CFString) throws {
		let query = baseQuery(service: service, account: account)
		let status = SecItemCopyMatching(query as CFDictionary, nil)
		switch status {
		case errSecItemNotFound:
			var attributes = query
			attributes[kSecValueData as String] = data
			attributes[kSecAttrAccessible as String] = accessibility
			let addStatus = SecItemAdd(attributes as CFDictionary, nil)
			guard addStatus == errSecSuccess else {
				throw DocumentKeychainError.unexpectedStatus(addStatus)
			}
		case errSecSuccess:
			let attributes: [String: Any] = [
				kSecValueData as String: data,
				kSecAttrAccessible as String: accessibility
			]
			let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
			guard updateStatus == errSecSuccess else {
				throw DocumentKeychainError.unexpectedStatus(updateStatus)
			}
		default:
			throw DocumentKeychainError.unexpectedStatus(status)
		}
	}

	/// A missing key is already the desired end state, so delete retries are safe.
	func remove(account: String, service: String) throws {
		let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
		guard status == errSecSuccess || status == errSecItemNotFound else {
			throw DocumentKeychainError.unexpectedStatus(status)
		}
	}

	private func baseQuery(service: String, account: String? = nil) -> [String: Any] {
		var query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			// Explicitly opt out of iCloud Keychain. Document keys and metadata
			// must remain on this device.
			kSecAttrSynchronizable as String: kCFBooleanFalse!
		]
		if let account = account {
			query[kSecAttrAccount as String] = account
		}
		return query
	}
}

enum DocumentAttachmentStoreError: Error, LocalizedError, Equatable {
	case keychain(DocumentKeychainError)
	case invalidKey
	case encryptionFailed
	case decryptionFailed
	case unsafePath
	case fileSystemFailure

	var errorDescription: String? {
		switch self {
		case .keychain:
			return "The document encryption key could not be accessed."
		case .invalidKey:
			return "The document encryption key is invalid."
		case .encryptionFailed:
			return "The document attachment could not be encrypted."
		case .decryptionFailed:
			return "The document attachment could not be decrypted."
		case .unsafePath:
			return "The document attachment path is invalid."
		case .fileSystemFailure:
			return "The encrypted document attachment could not be stored."
		}
	}
}

final class DocumentAttachmentStore {
	private static let attachmentDirectoryName = "DocumentAttachments"
	private static let keyServiceSuffix = ".documents.attachments.v1"

	private let rootDirectory: URL
	private let keyService: String
	private let keychain: DocumentKeychainClient
	private let fileManager: FileManager

	/// `rootDirectory`, `keyService`, and `keychain` are injectable for isolated
	/// tests. Production uses Application Support and an app-specific Keychain service.
	init(
		rootDirectory: URL? = nil,
		keyService: String? = nil,
		keychain: DocumentKeychainClient = SecurityDocumentKeychainClient(),
		fileManager: FileManager = .default
	) {
		self.fileManager = fileManager
		self.rootDirectory = (rootDirectory ?? Self.defaultRootDirectory(fileManager: fileManager)).standardizedFileURL
		self.keyService = keyService ?? Self.defaultKeyService
		self.keychain = keychain
	}

	@discardableResult
	func save(_ data: Data, for documentID: UUID, side: DocumentAttachmentSide) throws -> Bool {
		let existingKey = try encryptionKey(for: documentID, createsIfMissing: false)
		let createdKey = existingKey == nil
		let key: SymmetricKey
		if let existingKey {
			key = existingKey
		} else {
			guard let newKey = try encryptionKey(for: documentID) else {
				throw DocumentAttachmentStoreError.invalidKey
			}
			key = newKey
		}
		do {
			let sealedBox = try AES.GCM.seal(data, using: key)
			guard let encryptedData = sealedBox.combined else {
				throw DocumentAttachmentStoreError.encryptionFailed
			}
			try writeEncryptedData(encryptedData, for: documentID, side: side)
			return createdKey
		} catch let error as DocumentAttachmentStoreError {
			if createdKey { try deleteKey(for: documentID) }
			throw error
		} catch {
			if createdKey { try deleteKey(for: documentID) }
			throw DocumentAttachmentStoreError.encryptionFailed
		}
	}

	/// Captures ciphertext, not decrypted photo bytes, for a short rollback window
	/// while metadata is committed. It also permits replacing a corrupt old file.
	func encryptedAttachmentData(for documentID: UUID, side: DocumentAttachmentSide) throws -> Data? {
		let url = try attachmentURL(for: documentID, side: side)
		guard fileManager.fileExists(atPath: url.path) else { return nil }
		do {
			return try Data(contentsOf: url)
		} catch {
			throw DocumentAttachmentStoreError.fileSystemFailure
		}
	}

	func restoreEncryptedAttachmentData(
		_ data: Data?,
		for documentID: UUID,
		side: DocumentAttachmentSide
	) throws {
		if let data {
			try writeEncryptedData(data, for: documentID, side: side)
		} else {
			try deleteAttachment(for: documentID, side: side)
		}
	}

	func load(for documentID: UUID, side: DocumentAttachmentSide) throws -> Data? {
		let url = try attachmentURL(for: documentID, side: side)
		guard fileManager.fileExists(atPath: url.path) else {
			return nil
		}

		let encryptedData: Data
		do {
			encryptedData = try Data(contentsOf: url)
		} catch {
			throw DocumentAttachmentStoreError.fileSystemFailure
		}

		let key = try encryptionKey(for: documentID, createsIfMissing: false)
		guard let key = key else {
			return nil
		}
		do {
			let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
			return try AES.GCM.open(sealedBox, using: key)
		} catch {
			throw DocumentAttachmentStoreError.decryptionFailed
		}
	}

	func deleteAttachment(for documentID: UUID, side: DocumentAttachmentSide) throws {
		let url = try attachmentURL(for: documentID, side: side)
		guard fileManager.fileExists(atPath: url.path) else {
			return
		}
		do {
			try fileManager.removeItem(at: url)
			try removeEmptyDocumentDirectory(for: documentID)
		} catch let error as DocumentAttachmentStoreError {
			throw error
		} catch {
			throw DocumentAttachmentStoreError.fileSystemFailure
		}
	}

	/// Crypto-erasure is intentionally a distinct operation so callers can order
	/// deletion as key, encrypted files, then metadata.
	func deleteKey(for documentID: UUID) throws {
		do {
			try keychain.remove(account: documentID.uuidString, service: keyService)
		} catch let error as DocumentKeychainError {
			throw DocumentAttachmentStoreError.keychain(error)
		} catch {
			throw DocumentAttachmentStoreError.keychain(.unexpectedPayload)
		}
	}

	func deleteAttachments(for documentID: UUID) throws {
		for side in DocumentAttachmentSide.allCases {
			try deleteAttachment(for: documentID, side: side)
		}
		try removeEmptyDocumentDirectory(for: documentID)
	}

	/// Exposed at internal visibility for focused tests and recovery diagnostics.
	func attachmentURL(for documentID: UUID, side: DocumentAttachmentSide) throws -> URL {
		try documentDirectory(for: documentID).appendingPathComponent("\(side.rawValue).holder", isDirectory: false)
	}

	private func encryptionKey(for documentID: UUID, createsIfMissing: Bool = true) throws -> SymmetricKey? {
		do {
			if let keyData = try keychain.data(for: documentID.uuidString, service: keyService) {
				guard keyData.count == 32 else {
					throw DocumentAttachmentStoreError.invalidKey
				}
				return SymmetricKey(data: keyData)
			}

			guard createsIfMissing else {
				return nil
			}

			let key = SymmetricKey(size: .bits256)
			let keyData = key.withUnsafeBytes { Data($0) }
			try keychain.save(
				keyData,
				for: documentID.uuidString,
				service: keyService,
				accessibility: Self.deviceOnlyAccessibility
			)
			return key
		} catch let error as DocumentAttachmentStoreError {
			throw error
		} catch let error as DocumentKeychainError {
			throw DocumentAttachmentStoreError.keychain(error)
		} catch {
			throw DocumentAttachmentStoreError.keychain(.unexpectedPayload)
		}
	}

	private func writeEncryptedData(
		_ encryptedData: Data,
		for documentID: UUID,
		side: DocumentAttachmentSide
	) throws {
		let directory = try documentDirectory(for: documentID)
		let url = directory.appendingPathComponent("\(side.rawValue).holder", isDirectory: false)
		do {
			try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
			// Protect the directory before the atomic write so its temporary file
			// inherits Complete protection on iOS and visionOS.
			try applyCompleteFileProtection(to: directory)
			try excludeFromBackups(url: directory)
			try encryptedData.write(to: url, options: .atomic)
			try applyCompleteFileProtection(to: url)
			try excludeFromBackups(url: url)
		} catch let error as DocumentAttachmentStoreError {
			throw error
		} catch {
			throw DocumentAttachmentStoreError.fileSystemFailure
		}
	}

	private func documentDirectory(for documentID: UUID) throws -> URL {
		let root = rootDirectory.standardizedFileURL
		let directory = root.appendingPathComponent(documentID.uuidString, isDirectory: true).standardizedFileURL
		let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
		guard directory.path.hasPrefix(rootPath) else {
			throw DocumentAttachmentStoreError.unsafePath
		}
		return directory
	}

	private func removeEmptyDocumentDirectory(for documentID: UUID) throws {
		let directory = try documentDirectory(for: documentID)
		guard fileManager.fileExists(atPath: directory.path) else {
			return
		}
		do {
			if try fileManager.contentsOfDirectory(atPath: directory.path).isEmpty {
				try fileManager.removeItem(at: directory)
			}
		} catch {
			throw DocumentAttachmentStoreError.fileSystemFailure
		}
	}

	private func applyCompleteFileProtection(to url: URL) throws {
		#if os(iOS) || os(visionOS)
		do {
			try fileManager.setAttributes(
				[.protectionKey: FileProtectionType.complete],
				ofItemAtPath: url.path
			)
		} catch {
			throw DocumentAttachmentStoreError.fileSystemFailure
		}
		#endif
	}

	/// Encrypted photos are device-local application data, not a backup payload.
	/// This is separate from Keychain synchronisation: files in Application
	/// Support can otherwise be picked up by an encrypted device backup.
	private func excludeFromBackups(url: URL) throws {
		#if os(iOS) || os(visionOS)
		do {
			var values = URLResourceValues()
			values.isExcludedFromBackup = true
			var mutableURL = url
			try mutableURL.setResourceValues(values)
		} catch {
			throw DocumentAttachmentStoreError.fileSystemFailure
		}
		#endif
	}

	private static var defaultKeyService: String {
		"\(Bundle.main.bundleIdentifier ?? "com.swiftlysingh.cards")\(keyServiceSuffix)"
	}

	private static var deviceOnlyAccessibility: CFString {
		#if os(iOS) || os(visionOS) || targetEnvironment(macCatalyst)
			kSecAttrAccessibleWhenUnlockedThisDeviceOnly
		#else
			// macOS does not expose the iOS device-only class. Documents are still
			// stored in the app's local Keychain service there.
			kSecAttrAccessibleWhenUnlocked
		#endif
	}

	private static func defaultRootDirectory(fileManager: FileManager) -> URL {
		let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
			?? fileManager.temporaryDirectory
		return applicationSupport.appendingPathComponent(attachmentDirectoryName, isDirectory: true)
	}
}
