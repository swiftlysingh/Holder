//
//  WidgetCardData.swift
//  HolderWidgets
//
//  Lightweight card representation for widgets (no sensitive data)
//

import Foundation

/// Card data struct for widgets - only contains display-safe information
struct WidgetCardData: Codable, Identifiable, Hashable {
    let id: UUID
    let displayName: String
    let lastFourDigits: String
    let network: String

    var displayText: String {
		lastFourDigits.isEmpty ? "****" : "**** \(lastFourDigits)"
    }
}
