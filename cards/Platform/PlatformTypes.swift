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
