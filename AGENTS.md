## SinghDevKit

- Configure SinghDevKit once at app launch. Do not initialize Sentry, PostHog, or RevenueCat directly.
- Keep SDK-powered views below `.withSDK(sdk)`.
- Use `sdk.settingsView()` for Settings and keep app-specific controls on `SettingsViewModelProtocol`.
- Use typed analytics events and screens. Do not send card details or other user-entered content.
- Do not duplicate lifecycle, paywall, or purchase events owned by SinghDevKit.
- Provider keys live in Info.plist.
- Run `$integrate-singhdevkit` after adding or renaming significant screens, Settings controls, onboarding, entitlements, paywalls, or purchase flows.
