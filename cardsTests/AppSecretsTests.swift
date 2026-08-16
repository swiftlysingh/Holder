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
        XCTAssertNil(secrets.sentryDSN)
        XCTAssertEqual(secrets.analyticsConfiguration, .disabled)
        XCTAssertEqual(secrets.observabilityConfiguration, .disabled)
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
    }

    func testSentryDSNFromSecretsEnablesObservability() {
        let secrets = AppSecrets.load(
            from: ["SentryDSN": "  https://public@example.ingest.sentry.io/1  "],
            appConfiguration: [:]
        )

        XCTAssertEqual(secrets.sentryDSN, "https://public@example.ingest.sentry.io/1")
        XCTAssertEqual(
            secrets.observabilityConfiguration,
            .sentry(dsn: "https://public@example.ingest.sentry.io/1")
        )
    }

    func testSentryDSNFallsBackToInfoPlist() {
        let secrets = AppSecrets.load(
            from: [:],
            appConfiguration: ["SentryDSN": "https://public@example.ingest.sentry.io/2"]
        )

        XCTAssertEqual(secrets.sentryDSN, "https://public@example.ingest.sentry.io/2")
        XCTAssertEqual(
            secrets.observabilityConfiguration,
            .sentry(dsn: "https://public@example.ingest.sentry.io/2")
        )
    }

    func testSecretsSentryDSNOverridesInfoPlist() {
        let secrets = AppSecrets.load(
            from: ["SentryDSN": "https://secrets@example.ingest.sentry.io/3"],
            appConfiguration: ["SentryDSN": "https://plist@example.ingest.sentry.io/4"]
        )

        XCTAssertEqual(secrets.sentryDSN, "https://secrets@example.ingest.sentry.io/3")
    }

    func testBlankSentryDSNDisablesObservability() {
        let secrets = AppSecrets.load(
            from: ["SentryDSN": "   "],
            appConfiguration: ["SentryDSN": ""]
        )

        XCTAssertNil(secrets.sentryDSN)
        XCTAssertEqual(secrets.observabilityConfiguration, .disabled)
    }
}
