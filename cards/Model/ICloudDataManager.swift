//
//  ICloudDataManager.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 20/11/24.
//

import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Card image persistence. Implementations must not block the main thread.
protocol CardImageStore: AnyObject {
	func loadImage(for uuid: UUID) async -> PlatformImage?
	func saveImage(_ image: PlatformImage, for uuid: UUID) async -> Bool
	func deleteImage(for uuid: UUID) async
}

final class ICloudDataManager: CardImageStore {

	static let shared = ICloudDataManager()

	private let fileManager = FileManager.default
	private let ioQueue = DispatchQueue(label: "com.swiftlysingh.holder.icloud", qos: .userInitiated)
	private var cachedDirectory: URL?
	private var didResolveDirectory = false

	private init() {}

	func loadImage(for uuid: UUID) async -> PlatformImage? {
		await withCheckedContinuation { continuation in
			ioQueue.async {
				continuation.resume(returning: self.loadImageOnIOQueue(for: uuid))
			}
		}
	}

	func saveImage(_ image: PlatformImage, for uuid: UUID) async -> Bool {
		await withCheckedContinuation { continuation in
			ioQueue.async {
				continuation.resume(returning: self.saveImageOnIOQueue(image, for: uuid))
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
		if !didResolveDirectory {
			cachedDirectory = fileManager.url(forUbiquityContainerIdentifier: nil)?
				.appendingPathComponent("Documents")
			didResolveDirectory = true
			if cachedDirectory == nil {
				print("Warning: iCloud is not available. Images will not be synced across devices.")
			}
		}
		return cachedDirectory
	}

	private func getImageURLOnIOQueue(for uuid: UUID) -> URL? {
		resolveDirectoryOnIOQueue()?.appendingPathComponent("\(uuid.uuidString).jpg")
	}

	private func saveImageOnIOQueue(_ image: PlatformImage, for uuid: UUID) -> Bool {
		guard resolveDirectoryOnIOQueue() != nil else {
			print("Error: Cannot save image - iCloud is not available")
			return false
		}

		guard let imageData = image.jpegData(compressionQuality: 0.8),
			  let imageURL = getImageURLOnIOQueue(for: uuid) else {
			return false
		}

		do {
			if let directory = resolveDirectoryOnIOQueue() {
				try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
			}
			try imageData.write(to: imageURL)
			return true
		} catch {
			print("Error saving to iCloud: \(error)")
			return false
		}
	}

	private func loadImageOnIOQueue(for uuid: UUID) -> PlatformImage? {
		guard let imageURL = getImageURLOnIOQueue(for: uuid),
			  let imageData = try? Data(contentsOf: imageURL),
			  let image = PlatformImage(data: imageData) else {
			return nil
		}
		return image
	}

	private func deleteImageOnIOQueue(for uuid: UUID) {
		guard let imageURL = getImageURLOnIOQueue(for: uuid) else { return }
		try? fileManager.removeItem(at: imageURL)
	}
}
