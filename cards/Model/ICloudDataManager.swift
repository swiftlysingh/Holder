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
	func deleteImage(for uuid: UUID) async
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
		await withCheckedContinuation { continuation in
			ioQueue.async {
				continuation.resume(returning: self.loadImageDataOnIOQueue(for: uuid))
			}
		}
	}

	func saveImageData(_ data: Data, for uuid: UUID) async -> Bool {
		await withCheckedContinuation { continuation in
			ioQueue.async {
				continuation.resume(returning: self.saveImageDataOnIOQueue(data, for: uuid))
			}
		}
	}

	func deleteImage(for uuid: UUID) async {
		await withCheckedContinuation { continuation in
			ioQueue.async {
				self.deleteImageOnIOQueue(for: uuid)
				continuation.resume()
			}
		}
	}

	/// Apple documents `url(forUbiquityContainerIdentifier:)` as unsafe on the main
	/// thread because it can take several seconds. Always resolve it on `ioQueue`.
	private func resolveDirectoryOnIOQueue() -> URL? {
		dispatchPrecondition(condition: .onQueue(ioQueue))
		if let cachedDirectory {
			return cachedDirectory
		}

		guard let directory = directoryResolver() else {
			print("Warning: iCloud is not available. Images will not be synced across devices.")
			return nil
		}

		cachedDirectory = directory
		return directory
	}

	private func getImageURLOnIOQueue(for uuid: UUID) -> URL? {
		resolveDirectoryOnIOQueue()?.appendingPathComponent("\(uuid.uuidString).jpg")
	}

	private func saveImageDataOnIOQueue(_ data: Data, for uuid: UUID) -> Bool {
		guard let imageURL = getImageURLOnIOQueue(for: uuid) else {
			print("Error: Cannot save image - iCloud is not available")
			return false
		}

		do {
			try fileManager.createDirectory(
				at: imageURL.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try data.write(to: imageURL)
			return true
		} catch {
			print("Error saving to iCloud: \(error)")
			return false
		}
	}

	private func loadImageDataOnIOQueue(for uuid: UUID) -> Data? {
		guard let imageURL = getImageURLOnIOQueue(for: uuid) else { return nil }
		return try? Data(contentsOf: imageURL)
	}

	private func deleteImageOnIOQueue(for uuid: UUID) {
		guard let imageURL = getImageURLOnIOQueue(for: uuid) else { return }
		try? fileManager.removeItem(at: imageURL)
	}
}
