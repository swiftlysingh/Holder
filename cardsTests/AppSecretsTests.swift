import XCTest
@testable import Holder

final class AppSecretsTests: XCTestCase {
    func testMissingRevenueCatKeyDisablesOnlyPayments() throws {
        let secrets = try XCTUnwrap(AppSecrets.load(from: [
            "PostHogProjectToken": "posthog-token"
        ]))

        XCTAssertEqual(secrets.postHogProjectToken, "posthog-token")
        XCTAssertEqual(secrets.paymentsConfiguration, .disabled)
    }
}
