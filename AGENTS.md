## Build and Test Workflow

- Use `Scripts/agent-build.sh` instead of raw `xcodebuild` commands so builds reuse the shared Xcode compilation cache (CAS) and SwiftPM checkouts across worktrees while keeping per-worktree `DerivedData` isolated at `.build/DerivedData`.
- Compile check (iOS Simulator SDK, no simulator boot): `Scripts/agent-build.sh build`
- Unit tests (runs `cardsTests` and skips parallel simulator clones and UI tests by default): `Scripts/agent-build.sh test` (or `--only-testing cardsTests/<TestClass>` for targeted runs)
- When iterating on tests without source changes, use `Scripts/agent-build.sh build-for-testing` followed by `Scripts/agent-build.sh test-without-building`.
- Keep all local agent build and test checks on the iOS Simulator SDK so they share one compilation cache; do not mix `generic/platform=iOS` unless verifying device signing/archiving.
- Pass `--timing` for `-showBuildTimingSummary` or `--jobs 4` when running multiple agents in parallel.

## SinghDevKit

- Configure SinghDevKit once at app launch. Do not initialize Sentry, PostHog, or RevenueCat directly.
- Keep SDK-powered views below `.withSDK(sdk)`.
- Use `sdk.settingsView()` for Settings and keep app-specific controls on `SettingsViewModelProtocol`.
- Use typed analytics events and screens. Do not send card details or other user-entered content.
- Do not duplicate lifecycle, paywall, or purchase events owned by SinghDevKit.
- Provider keys live in Info.plist.
- Run `$integrate-singhdevkit` after adding or renaming significant screens, Settings controls, onboarding, entitlements, paywalls, or purchase flows.
