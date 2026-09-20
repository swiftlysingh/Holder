//
//  PlatformTypes.swift
//  cards
//
//  Cross-platform type aliases and utilities
//

import Foundation
import ImageIO

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

enum CardImageData {
	/// Longest edge stored and decoded for card photos. Camera-roll images can
	/// be tens of megapixels; `UIImage(data:)` / `NSImage(data:)` leave that
	/// decode until first draw, which hangs the main thread in malloc.
	static let maxPixelSize = 2048

	static func decodeOffMain(_ data: Data) async -> PlatformImage? {
		await Task.detached(priority: .userInitiated) {
			downsampledImage(from: data)
		}.value
	}

	/// Decodes with ImageIO thumbnails and caches the bitmap immediately so
	/// SwiftUI's first paint does not expand a full-resolution JPEG on main.
	static func downsampledImage(from data: Data, maxPixelSize: Int = maxPixelSize) -> PlatformImage? {
		guard let cgImage = thumbnailCGImage(from: data, maxPixelSize: maxPixelSize) else {
			return nil
		}
		return platformImage(from: cgImage)
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

	/// Matches Holder's existing JPEG storage contract without carrying source metadata.
	static func normalizedJPEG(
		from data: Data,
		compressionQuality: CGFloat = 0.8,
		maxPixelSize: Int = maxPixelSize
	) -> Data? {
		guard let cgImage = thumbnailCGImage(from: data, maxPixelSize: maxPixelSize) else { return nil }
		return jpegData(from: cgImage, compressionQuality: compressionQuality)
	}

	private static let sourceOptions: CFDictionary = [
		kCGImageSourceShouldCache: false
	] as CFDictionary

	private static func thumbnailCGImage(from data: Data, maxPixelSize: Int = maxPixelSize) -> CGImage? {
		guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
			return nil
		}
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceShouldCacheImmediately: true,
			kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
		]
		return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
	}

	private static func platformImage(from cgImage: CGImage) -> PlatformImage {
		#if os(macOS)
		NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
		#else
		UIImage(cgImage: cgImage)
		#endif
	}

	private static func jpegData(from cgImage: CGImage, compressionQuality: CGFloat) -> Data? {
		let data = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(
			data,
			"public.jpeg" as CFString,
			1,
			nil
		) else {
			return nil
		}
		let properties: [CFString: Any] = [
			kCGImageDestinationLossyCompressionQuality: compressionQuality
		]
		CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
		guard CGImageDestinationFinalize(destination) else { return nil }
		return data as Data
	}
}
