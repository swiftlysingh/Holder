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
        case success
        case error
        case warning
    }

    static func trigger(_ type: FeedbackType) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .success:
            generator.notificationOccurred(.success)
        case .error:
            generator.notificationOccurred(.error)
        case .warning:
            generator.notificationOccurred(.warning)
        }
        #endif
        // No haptic feedback on macOS - silent no-op
    }
}
