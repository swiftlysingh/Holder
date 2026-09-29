import SwiftUI
import XCTest
@testable import Holder

final class HangSafeUITests: XCTestCase {
	func testDataCommitTransactionDisablesAnimations() {
		XCTAssertTrue(HangSafeUI.dataCommitTransaction().disablesAnimations)
	}

	func testWithoutTextAnimationRunsUpdates() {
		var didRun = false
		HangSafeUI.withoutTextAnimation {
			didRun = true
		}
		XCTAssertTrue(didRun)
	}
}
