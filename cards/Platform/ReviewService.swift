import StoreKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ReviewService {
    static func requestReview() {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: windowScene)
        #elseif os(macOS)
        guard let controller = (NSApp.keyWindow ?? NSApp.mainWindow)?.contentViewController else { return }
        AppStore.requestReview(in: controller)
        #endif
    }
}
