//
//  PlatformTypes.swift
//  cards
//
//  Cross-platform type aliases and utilities
//

import Foundation

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

enum CardImageData {
	static func decodeOffMain(_ data: Data) async -> PlatformImage? {
		await Task.detached(priority: .userInitiated) {
			PlatformImage(data: data)
		}.value
	}

	/// Matches Holder's existing JPEG storage contract without carrying source metadata.
	static func normalizedJPEG(from data: Data, compressionQuality: CGFloat = 0.8) -> Data? {
		#if os(macOS)
		guard let image = NSImage(data: data),
		      let tiffData = image.tiffRepresentation,
		      let bitmap = NSBitmapImageRep(data: tiffData) else {
			return nil
		}
		return bitmap.representation(
			using: .jpeg,
			properties: [.compressionFactor: compressionQuality]
		)
		#else
		return UIImage(data: data)?.jpegData(compressionQuality: compressionQuality)
		#endif
	}
}
