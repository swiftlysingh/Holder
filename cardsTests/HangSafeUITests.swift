import SwiftUI
import XCTest
@testable import Holder

final class HangSafeUITests: XCTestCase {
	func testDataCommitTransactionDisablesAnimations() {
		XCTAssertTrue(HangSafeUI.dataCommitTransaction().disablesAnimations)
	}
}
