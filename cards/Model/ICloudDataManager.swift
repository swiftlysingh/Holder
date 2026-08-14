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

class ICloudDataManager {

	private init () {
		// Log iCloud availability on initialization
		if !isICloudAvailable {
			print("Warning: iCloud is not available. Images will not be synced across devices.")
		}
	}

	static let shared = ICloudDataManager()

	private let fileManager = FileManager.default

	/// Indicates whether iCloud storage is available
	var isICloudAvailable: Bool {
		cloudDirectory != nil
	}

	private var cloudDirectory: URL? {
		fileManager.url(forUbiquityContainerIdentifier: nil)?
			.appendingPathComponent("Documents")
	}

	private func getImageURL(for uuid: UUID) -> URL? {
		return cloudDirectory?.appendingPathComponent("\(uuid.uuidString).jpg")
	}

	func saveImage(_ image: PlatformImage, for uuid: UUID) -> Bool {
		guard isICloudAvailable else {
			print("Error: Cannot save image - iCloud is not available")
			return false
		}

		guard let imageData = image.jpegData(compressionQuality: 0.8),
			  let imageURL = getImageURL(for: uuid) else {
			return false
		}

		do {
			if let directory = cloudDirectory {
				try fileManager.createDirectory(at: directory,
												withIntermediateDirectories: true)
			}
			try imageData.write(to: imageURL)
			return true
		} catch {
			print("Error saving to iCloud: \(error)")
			return false
		}
	}

	func loadImage(for uuid: UUID) -> PlatformImage? {
		guard let imageData = loadImageData(for: uuid),
			  let image = PlatformImage(data: imageData) else {
			return nil
		}
		return image
	}

	/// Reads the exact legacy JPEG bytes for the explicit, verified migration
	/// path into the encrypted device-local document vault.
	func loadImageData(for uuid: UUID) -> Data? {
		guard let imageURL = getImageURL(for: uuid) else { return nil }
		return try? Data(contentsOf: imageURL)
	}

	/// Removes a legacy Other Card image from iCloud before its Keychain metadata is deleted.
	/// Returns `false` when iCloud is unavailable or the removal fails so callers can keep
	/// the visible card record and offer a retry instead of silently orphaning plaintext data.
	@discardableResult
	func deleteImage(for uuid: UUID) -> Bool {
		guard let imageURL = getImageURL(for: uuid) else {
			print("Error: Cannot delete legacy image - iCloud is not available")
			return false
		}

		do {
			// Attempt removal even when there is no downloaded local representation.
			// Ubiquitous items can be evicted placeholders while still existing remotely.
			try fileManager.removeItem(at: imageURL)
			return true
		} catch let error as CocoaError where error.code == .fileNoSuchFile {
			// A confirmed missing item is already the desired idempotent state.
			return true
		} catch {
			print("Error deleting legacy iCloud image: \(error)")
			return false
		}
	}
}
