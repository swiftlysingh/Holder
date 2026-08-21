//
//  ICloudDataManager.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 20/11/24.
//

import Foundation
import ImageIO

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class ICloudDataManager {

	/// Longest edge stored and decoded for card photos. Camera roll images can be
	/// 48MP; decoding those as `UIImage`/`NSImage` is enough to jetsam Holder.
	static let maxPixelSize = 2048

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

		let imageToWrite = Self.constrainedImage(image)
		guard let imageData = imageToWrite.jpegData(compressionQuality: 0.8),
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
		guard let imageURL = getImageURL(for: uuid) else {
			return nil
		}
		return Self.downsampledImage(fromFile: imageURL)
	}

	func deleteImage(for uuid: UUID) {
		guard let imageURL = getImageURL(for: uuid) else { return }
		try? fileManager.removeItem(at: imageURL)
	}

	/// Decodes `data` with ImageIO thumbnails so the full bitmap is never materialized.
	static func downsampledImage(from data: Data, maxPixelSize: Int = maxPixelSize) -> PlatformImage? {
		guard let source = CGImageSourceCreateWithData(data as CFData, Self.sourceOptions) else {
			return nil
		}
		return image(from: source, maxPixelSize: maxPixelSize)
	}

	/// Decodes a file with ImageIO thumbnails so `Data(contentsOf:)` is not required.
	static func downsampledImage(fromFile url: URL, maxPixelSize: Int = maxPixelSize) -> PlatformImage? {
		guard let source = CGImageSourceCreateWithURL(url as CFURL, Self.sourceOptions) else {
			return nil
		}
		return image(from: source, maxPixelSize: maxPixelSize)
	}

	static func pixelSize(of image: PlatformImage) -> CGSize {
		#if os(macOS)
		if let representation = image.representations.first {
			return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
		}
		return image.size
		#else
		return CGSize(
			width: image.size.width * image.scale,
			height: image.size.height * image.scale
		)
		#endif
	}

	static func constrainedImage(_ image: PlatformImage, maxPixelSize: Int = maxPixelSize) -> PlatformImage {
		let size = pixelSize(of: image)
		guard max(size.width, size.height) > CGFloat(maxPixelSize) else {
			return image
		}

		#if os(iOS)
		let thumbnailSize = CGSize(width: maxPixelSize, height: maxPixelSize)
		return image.preparingThumbnail(of: thumbnailSize) ?? image
		#else
		guard let data = image.jpegData(compressionQuality: 1),
			  let downsampled = downsampledImage(from: data, maxPixelSize: maxPixelSize) else {
			return image
		}
		return downsampled
		#endif
	}

	private static let sourceOptions: CFDictionary = [
		kCGImageSourceShouldCache: false
	] as CFDictionary

	private static func image(from source: CGImageSource, maxPixelSize: Int) -> PlatformImage? {
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceShouldCacheImmediately: true,
			kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
		]
		guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
			return nil
		}
		return platformImage(from: cgImage)
	}

	private static func platformImage(from cgImage: CGImage) -> PlatformImage {
		#if os(macOS)
		NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
		#else
		UIImage(cgImage: cgImage)
		#endif
	}
}
