//
//  PasteboardService.swift
//  cards
//
//  Cross-platform clipboard access
//

import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct PasteboardService {
    static func copy(_ string: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        #else
        UIPasteboard.general.string = string
        #endif
    }
}
