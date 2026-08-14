//
//  HolderWidgetPalette.swift
//  HolderWidgets
//
//  Shared visual tokens for the Holder widget family.
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// A deliberately small palette that mirrors Holder's Emerald Mint system.
///
/// Home-screen card data is marked privacy-sensitive by the views that use it.
/// Lock-screen inline families use only the widget-safe display label and a
/// masked tail; Control Center remains generic state only.
enum HolderWidgetPalette {
    static let mintCanvas = adaptiveColor(
        light: (red: 0.935, green: 0.975, blue: 0.945),
        dark: (red: 0.055, green: 0.105, blue: 0.090),
        highContrastLight: (red: 0.985, green: 1, blue: 0.990),
        highContrastDark: (red: 0.015, green: 0.045, blue: 0.030)
    )

    static let ink = Color(red: 0.055, green: 0.205, blue: 0.170)
    static let emerald = adaptiveColor(
        light: (red: 0.040, green: 0.330, blue: 0.245),
        dark: (red: 0.275, green: 0.851, blue: 0.627),
        highContrastLight: (red: 0.010, green: 0.235, blue: 0.165),
        highContrastDark: (red: 0.700, green: 0.980, blue: 0.810)
    )
    static let secondaryOnCard = Color.white.opacity(0.74)
    static let secondaryOnCanvas = adaptiveColor(
        light: (red: 0.235, green: 0.385, blue: 0.335),
        dark: (red: 0.690, green: 0.790, blue: 0.735),
        highContrastLight: (red: 0.070, green: 0.220, blue: 0.165),
        highContrastDark: (red: 0.865, green: 0.955, blue: 0.900)
    )

    /// Fixed-lightness content slots keep multi-card widgets legible while
    /// giving cards a little visual differentiation without exposing data.
    private static let cardSurfaces: [Color] = [
        Color(red: 0.055, green: 0.205, blue: 0.170),
        Color(red: 0.155, green: 0.190, blue: 0.400),
        Color(red: 0.075, green: 0.265, blue: 0.155),
        Color(red: 0.350, green: 0.145, blue: 0.115),
        Color(red: 0.270, green: 0.145, blue: 0.320)
    ]

    static func cardSurface(for card: WidgetCardData) -> Color {
        let stableValue = card.id.uuidString.utf8.reduce(0) { partialResult, byte in
            partialResult + Int(byte)
        }
        return cardSurfaces[stableValue % cardSurfaces.count]
    }

    static func smallBackground(for card: WidgetCardData?) -> Color {
        guard let card else { return mintCanvas }
        return cardSurface(for: card)
    }

    private static func adaptiveColor(
        light: (red: CGFloat, green: CGFloat, blue: CGFloat),
        dark: (red: CGFloat, green: CGFloat, blue: CGFloat),
        highContrastLight: (red: CGFloat, green: CGFloat, blue: CGFloat),
        highContrastDark: (red: CGFloat, green: CGFloat, blue: CGFloat)
    ) -> Color {
        #if os(iOS)
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let components: (red: CGFloat, green: CGFloat, blue: CGFloat)

            if traits.accessibilityContrast == .high {
                components = isDark ? highContrastDark : highContrastLight
            } else {
                components = isDark ? dark : light
            }

            return UIColor(
                red: components.red,
                green: components.green,
                blue: components.blue,
                alpha: 1
            )
        })
        #elseif os(macOS)
        Color(nsColor: NSColor(name: nil) { appearance in
            let darkMatches: [NSAppearance.Name] = [
                .accessibilityHighContrastDarkAqua,
                .darkAqua
            ]
            let highContrastMatches: [NSAppearance.Name] = [
                .accessibilityHighContrastDarkAqua,
                .accessibilityHighContrastAqua
            ]
            let isDark = appearance.bestMatch(from: darkMatches) != nil
            let isHighContrast = appearance.bestMatch(from: highContrastMatches) != nil
            let components: (red: CGFloat, green: CGFloat, blue: CGFloat)

            if isHighContrast {
                components = isDark ? highContrastDark : highContrastLight
            } else {
                components = isDark ? dark : light
            }

            return NSColor(
                red: components.red,
                green: components.green,
                blue: components.blue,
                alpha: 1
            )
        })
        #else
        Color(red: light.red, green: light.green, blue: light.blue)
        #endif
    }
}

enum HolderWidgetURL {
    static func card(_ id: UUID) -> URL? {
        URL(string: "holder://card/\(id.uuidString)")
    }

    static func card(_ card: WidgetCardData) -> URL? {
        HolderWidgetURL.card(card.id)
    }
}
