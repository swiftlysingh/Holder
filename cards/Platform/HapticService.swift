//
//  HapticService.swift
//  cards
//
//  Cross-platform haptic feedback (no-op on macOS)
//

import Foundation

#if os(iOS)
import UIKit
#endif

struct HapticService {
    enum FeedbackType {
        case light
        case success
        case error
        case warning
    }

    static func trigger(_ type: FeedbackType) {
        #if os(iOS)
        switch type {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        #endif
        // No haptic feedback on macOS - silent no-op
    }
}
