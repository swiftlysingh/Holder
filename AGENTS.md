## SinghDevKit

- Import and configure SinghDevKit once; do not initialize Sentry, PostHog, or RevenueCat directly.
- Keep SDK-powered views below `.withSDK(sdk)`.
- Construct `SinghDevKit(configuration:)` at the app entry point; do not add a separate client configuration task.
- Use SDKSettingsView for the app's Settings destination and preserve app-specific controls through SettingsViewModelProtocol.
- Use SinghDevKit for onboarding, diagnostics, payments, entitlement checks, paywalls, Customer Center, analytics transport, and SDK-owned events when those capabilities apply.
- Define product events as typed AnalyticsEvent values.
- Define screen names as typed AnalyticsScreen values.
- Give every typed event an intentional AnalyticsCrashContext policy; allowlist only safe scalar properties.
- Do not use raw event strings outside the analytics catalog.
- Use ErrorReportingClient and stable ErrorReport fields for actionable handled errors; analytics events never create Sentry issues.
- Never record user-entered financial or personal content.
- Do not duplicate lifecycle, paywall or purchase events owned by SinghDevKit.
- Keep provider credentials in the app's existing secrets mechanism.
- Keep PostHog crash autocapture off and complete provider-side, built-app, release-crash, and symbolication proof before claiming sole crash ownership.
- Run `$integrate-singhdevkit` after adding or renaming significant screens, Settings controls, onboarding steps, entitlements, paywalls, or purchase flows.
