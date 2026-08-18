import Foundation
import XCTest
@testable import Holder

final class AppSecretsTests: XCTestCase {
    func testEmptyConfigurationDisablesOptionalProviders() {
        let secrets = AppSecrets.load(from: ["RevenueCatAPIKey": "  appl_test_key  "])

        XCTAssertNil(secrets.postHogProjectToken)
        XCTAssertNil(secrets.sentryDSN)
        XCTAssertEqual(secrets.analyticsConfiguration, .disabled)
        XCTAssertEqual(secrets.observabilityConfiguration, .disabled)
        XCTAssertEqual(secrets.paymentsConfiguration, .revenueCat(apiKey: "appl_test_key"))
    }

    func testMissingRevenueCatPublicKeyDisablesOnlyPayments() {
        let secrets = AppSecrets.load(
            from: [
                "PostHogProjectToken": "posthog-token",
                "RevenueCatAPIKey": "   "
            ]
        )

        XCTAssertEqual(secrets.postHogProjectToken, "posthog-token")
        XCTAssertNotEqual(secrets.analyticsConfiguration, .disabled)
        XCTAssertEqual(secrets.paymentsConfiguration, .disabled)
    }

    func testPostHogConfigurationUsesConfiguredHost() {
        let secrets = AppSecrets.load(
            from: [
                "PostHogProjectToken": "  posthog-token  ",
                "PostHogHost": "https://example.com",
                "RevenueCatAPIKey": "appl_test_key"
            ]
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
            from: [
                "PostHogProjectToken": "posthog-token",
                "RevenueCatAPIKey": "appl_test_key"
            ]
        )

        XCTAssertEqual(secrets.postHogHost, URL(string: "https://us.i.posthog.com"))
    }

    func testSentryDSNEnablesObservability() {
        let secrets = AppSecrets.load(
            from: ["SentryDSN": "  https://public@example.ingest.sentry.io/1  "]
        )

        XCTAssertEqual(secrets.sentryDSN, "https://public@example.ingest.sentry.io/1")
        XCTAssertEqual(
            secrets.observabilityConfiguration,
            .sentry(
                dsn: "https://public@example.ingest.sentry.io/1",
                environment: AppSecrets.sentryEnvironment,
                release: AppSecrets.sentryRelease
            )
        )
    }

    func testBlankSentryDSNDisablesObservability() {
        let secrets = AppSecrets.load(from: ["SentryDSN": "   "])

        XCTAssertNil(secrets.sentryDSN)
        XCTAssertEqual(secrets.observabilityConfiguration, .disabled)
    }
}
