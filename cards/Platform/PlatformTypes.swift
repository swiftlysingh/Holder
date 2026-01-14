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

// MARK: - PlatformImage Extensions

extension PlatformImage {
    #if os(macOS)
    /// Convert NSImage to JPEG data for macOS
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    #endif
}
