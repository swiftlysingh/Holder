//
//  ReviewService.swift
//  cards
//
//  Cross-platform App Store review request
//

import StoreKit

#if os(iOS)
import UIKit
#endif

struct ReviewService {
    static func requestReview() {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: windowScene)
        #elseif os(macOS)
        SKStoreReviewController.requestReview()
        #endif
    }
}
