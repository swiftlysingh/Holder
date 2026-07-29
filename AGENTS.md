## SinghDevKit

- Import and configure SinghDevKit once; do not initialize PostHog or RevenueCat directly.
- Keep SDK-powered views below `.withSDK(sdk)`.
- Use SDK Settings (`sdk.settingsView()` / `SDKSettingsView`) as the app's Settings destination and preserve app-specific controls through `SettingsViewModelProtocol`.
- Use SinghDevKit for onboarding, payments, entitlement checks, paywalls, Customer Center, analytics transport, and SDK-owned events when those capabilities apply.
- Define product events as typed `AnalyticsEvent` values and screen names as typed `AnalyticsScreen` values.
- Do not use raw event strings outside the analytics catalog, and do not call PostHog or RevenueCat directly.
- Never record personal, financial, or user-entered content in analytics.
- Do not duplicate lifecycle, paywall, or purchase events owned by SinghDevKit.
- Keep provider credentials in the app's existing secrets mechanism.
- Run `$integrate-singhdevkit` after adding or renaming significant screens, Settings controls, onboarding steps, entitlements, paywalls, or purchase flows.
