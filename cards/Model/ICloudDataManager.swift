//
//  ICloudDataManager.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 20/11/24.
//

import Foundation

/// Card image persistence. Implementations must not block the main thread.
protocol CardImageStore: AnyObject, Sendable {
	func loadImageData(for uuid: UUID) async -> Data?
	func saveImageData(_ data: Data, for uuid: UUID) async -> Bool
	func deleteImage(for uuid: UUID) async -> Bool
}

/// `ioQueue` serializes all mutable state and every resolver/file operation.
final class ICloudDataManager: CardImageStore, @unchecked Sendable {

	static let shared = ICloudDataManager()

	private let fileManager = FileManager.default
	private let ioQueue = DispatchQueue(label: "com.swiftlysingh.holder.icloud", qos: .userInitiated)
	private let directoryResolver: @Sendable () -> URL?
	private var cachedDirectory: URL?

	private init() {
		directoryResolver = {
			FileManager.default.url(forUbiquityContainerIdentifier: nil)?
				.appendingPathComponent("Documents")
		}
	}

	init(directoryResolver: @escaping @Sendable () -> URL?) {
		self.directoryResolver = directoryResolver
	}

	func loadImageData(for uuid: UUID) async -> Data? {
		await performOnIOQueue { manager in
			manager.loadImageDataOnIOQueue(for: uuid)
		}
	}

	func saveImageData(_ data: Data, for uuid: UUID) async -> Bool {
		await performOnIOQueue { manager in
			manager.saveImageDataOnIOQueue(data, for: uuid)
		}
	}

	func deleteImage(for uuid: UUID) async -> Bool {
		await performOnIOQueue { manager in
			manager.deleteImageOnIOQueue(for: uuid)
		}
	}

	private func performOnIOQueue<Value: Sendable>(
		_ operation: @escaping @Sendable (ICloudDataManager) -> Value
	) async -> Value {
		await withCheckedContinuation { continuation in
			ioQueue.async {
				continuation.resume(returning: operation(self))
			}
		}
	}

	/// Apple documents `url(forUbiquityContainerIdentifier:)` as unsafe on the main
	/// thread because it can take several seconds. Always resolve it on `ioQueue`.
	private func directoryOnIOQueue() -> URL? {
		dispatchPrecondition(condition: .onQueue(ioQueue))
		if let cachedDirectory {
			return cachedDirectory
		}

		guard let directory = directoryResolver() else {
			print("Warning: iCloud is not available. Images will not be synced across devices.")
			return nil
		}

		do {
			try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
			cachedDirectory = directory
			return directory
		} catch {
			print("Error preparing iCloud directory: \(error)")
			return nil
		}
	}

	private func getImageURLOnIOQueue(for uuid: UUID) -> URL? {
		directoryOnIOQueue()?.appendingPathComponent("\(uuid.uuidString).jpg")
	}

	private func saveImageDataOnIOQueue(_ data: Data, for uuid: UUID) -> Bool {
		guard let imageURL = getImageURLOnIOQueue(for: uuid) else {
			print("Error: Cannot save image - iCloud is not available")
			return false
		}
		guard let jpegData = CardImageData.normalizedJPEG(from: data) else {
			print("Error: Cannot save image - unsupported image data")
			return false
		}

		do {
			try jpegData.write(to: imageURL, options: .atomic)
			return true
		} catch {
			cachedDirectory = nil
			print("Error saving to iCloud: \(error)")
			return false
		}
	}

	private func loadImageDataOnIOQueue(for uuid: UUID) -> Data? {
		guard let imageURL = getImageURLOnIOQueue(for: uuid) else { return nil }
		do {
			return try Data(contentsOf: imageURL)
		} catch {
			if !isFileNotFound(error) {
				cachedDirectory = nil
			}
			return nil
		}
	}

	private func deleteImageOnIOQueue(for uuid: UUID) -> Bool {
		guard let imageURL = getImageURLOnIOQueue(for: uuid) else { return false }
		do {
			try fileManager.removeItem(at: imageURL)
			return true
		} catch {
			if isFileNotFound(error) {
				return true
			}
			cachedDirectory = nil
			print("Error deleting from iCloud: \(error)")
			return false
		}
	}

	private func isFileNotFound(_ error: Error) -> Bool {
		let cocoaError = error as NSError
		return cocoaError.domain == NSCocoaErrorDomain
			&& cocoaError.code == CocoaError.Code.fileNoSuchFile.rawValue
	}
}
