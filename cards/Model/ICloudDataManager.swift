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

	private init () {}

	static let shared = ICloudDataManager()

	private let fileManager = FileManager.default

	private var cloudDirectory: URL? {
		fileManager.url(forUbiquityContainerIdentifier: nil)?
			.appendingPathComponent("Documents")
	}

	private func getImageURL(for uuid: UUID) -> URL? {
		return cloudDirectory?.appendingPathComponent("\(uuid.uuidString).jpg")
	}

	func saveImage(_ image: PlatformImage, for uuid: UUID) -> Bool {
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
		guard let imageURL = getImageURL(for: uuid),
			  let imageData = try? Data(contentsOf: imageURL),
			  let image = PlatformImage(data: imageData) else {
			return nil
		}
		return image
	}

	func deleteImage(for uuid: UUID) {
		guard let imageURL = getImageURL(for: uuid) else { return }
		try? fileManager.removeItem(at: imageURL)
	}
}
