import SwiftUI
import XCTest
@testable import Holder

final class HangSafeUITests: XCTestCase {
	@MainActor
	func testDataCommitTransactionDisablesAnimations() async {
		XCTAssertTrue(HangSafeUI.dataCommitTransaction().disablesAnimations)
	}

	@MainActor
	func testWithoutTextAnimationRunsUpdates() async {
		var didRun = false
		HangSafeUI.withoutTextAnimation {
			didRun = true
		}
		XCTAssertTrue(didRun)
	}
}
