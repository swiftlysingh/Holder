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
    let cardType: String
    let network: String

    var displayText: String {
        "**** \(lastFourDigits)"
    }
}

/// Card type enum (mirrored from main app)
enum WidgetCardType: String, CaseIterable, Identifiable, Codable {
    var id: Self { self }

    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case otherCard = "Other Card"
}

/// Card network enum (mirrored from main app)
enum WidgetCardNetwork: String, CaseIterable, Identifiable, Codable {
    var id: Self { self }

    case visa = "Visa"
    case master = "Mastercard"
    case amex = "Amex"
    case diners = "Diners"
    case rupay = "Rupay"
    case discover = "Discover"
    case jcb = "JCB"
    case unionPay = "UnionPay"
    case other = "Unknown"
}
