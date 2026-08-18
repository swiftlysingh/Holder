import Foundation
import XCTest
@testable import Holder

final class AppSecretsTests: XCTestCase {
    func testEmptySecretsEnableRevenueCatFromPublicConfiguration() {
        let secrets = AppSecrets.load(
            from: [:],
            appConfiguration: ["RevenueCatAPIKey": "  appl_test_key  "]
        )

        XCTAssertNil(secrets.postHogProjectToken)
        XCTAssertEqual(secrets.analyticsConfiguration, .disabled)
        XCTAssertEqual(secrets.paymentsConfiguration, .revenueCat(apiKey: "appl_test_key"))
    }

    func testMissingRevenueCatPublicKeyDisablesOnlyPayments() {
        let secrets = AppSecrets.load(
            from: ["PostHogProjectToken": "posthog-token"],
            appConfiguration: ["RevenueCatAPIKey": "   "]
        )

        XCTAssertEqual(secrets.postHogProjectToken, "posthog-token")
        XCTAssertNotEqual(secrets.analyticsConfiguration, .disabled)
        XCTAssertEqual(secrets.paymentsConfiguration, .disabled)
    }

    func testPostHogConfigurationUsesConfiguredHost() {
        let secrets = AppSecrets.load(
            from: [
                "PostHogProjectToken": "  posthog-token  ",
                "PostHogHost": "https://example.com"
            ],
            appConfiguration: ["RevenueCatAPIKey": "appl_test_key"]
        )

        XCTAssertEqual(secrets.postHogProjectToken, "posthog-token")
        XCTAssertEqual(secrets.postHogHost, URL(string: "https://example.com"))
        XCTAssertEqual(
            secrets.analyticsConfiguration,
            .postHog(
                projectToken: "posthog-token",
                host: URL(string: "https://example.com")!
            )
        )
    }

    func testPostHogConfigurationDefaultsHost() {
        let secrets = AppSecrets.load(
            from: ["PostHogProjectToken": "posthog-token"],
            appConfiguration: ["RevenueCatAPIKey": "appl_test_key"]
        )

        XCTAssertEqual(secrets.postHogHost, URL(string: "https://us.i.posthog.com"))
        XCTAssertNil(secrets.scanbotLicenseKey)
    }

    func testScanbotLicenseKeyLoadsFromSecrets() {
        let secrets = AppSecrets.load(
            from: ["ScanbotLicenseKey": "  trial-key  "],
            appConfiguration: [:]
        )

        XCTAssertEqual(secrets.scanbotLicenseKey, "trial-key")
    }
}
