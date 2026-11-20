import SwiftUI

class UserSettings : ObservableObject {
	static let shared = UserSettings()
	private init (){}

    @AppStorage("keepInMenuBar") var keepInMenuBar = false

    func requestReview() {
        ReviewService.requestReview()
    }
}
