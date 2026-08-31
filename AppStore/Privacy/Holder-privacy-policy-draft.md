# Holder Privacy Policy

> Draft for owner and legal review. This file has not been published and is not the policy currently linked from the App Store.

Last updated: August 26, 2026

Holder is built by Pushpinder Pal Singh. This policy explains what Holder stores, what limited information is sent to service providers, and the choices available to you.

## Card details

Holder stores the card details you choose to save, which may include a card number, security code, expiration date, name, description, card type, network, and archive status.

Card details are stored in Apple Keychain. If iCloud Keychain is enabled for your Apple Account and devices, Apple may synchronize those details according to your iCloud settings. Holder does not operate a server that receives or stores your card details.

Card images are optional. If you add one, Holder stores it in the app's iCloud Documents container. Card images are not stored in Keychain and are subject to Apple's iCloud synchronization, backup, retention, and security practices.

Deleting a card asks Holder to delete its Keychain record and associated card image. Copies retained by Apple through synchronization or backup may remain according to Apple's policies and your iCloud settings.

## Card scanning

Card scanning is processed on your device using Apple frameworks. Holder does not send camera images, recognized text, card numbers, names, expiration dates, or security codes to Holder, PostHog, Sentry, or RevenueCat for scanning.

Holder may send limited scanner-performance events to PostHog, such as the scanner engine used, whether individual fields were recognized, how long the scan took, and whether you tried again. These events do not contain the recognized card values or camera images.

## App analytics

Holder uses PostHog to understand app reliability and how features are used. PostHog receives a pseudonymous identifier generated for the app installation and limited information such as:

- App version and build
- Device model and platform
- Operating-system version
- Language and time zone
- Screen dimensions
- General connectivity state
- App lifecycle, feature-action, and success or failure events
- Aggregated performance and diagnostic summaries

Holder does not use a Holder account to identify you in PostHog and does not send card contents, names stored on cards, security codes, recognized text, card images, or clipboard contents as analytics properties.

PostHog controls its own processing and retention practices. See the [PostHog Privacy Policy](https://posthog.com/privacy).

## Crash reports and diagnostics

Holder uses Sentry to receive sanitized crash, app-hang, and diagnostic information. This may include the app version, operating-system and device details, an error category or code, and information needed to understand where a failure occurred.

Holder disables default personal-information collection, screenshots, view hierarchies, session replay, network payloads, and raw MetricKit payload forwarding in its Sentry configuration. Sentry may still process provider-side network or technical metadata according to its policies.

See the [Sentry Privacy Policy](https://sentry.io/privacy/).

## Purchases and subscriptions

Purchases and subscriptions are processed through Apple and RevenueCat. They may receive purchase history, product and offering identifiers, subscription status, transaction outcomes, an anonymous RevenueCat customer identifier, and technical identifiers or network information made available to their SDKs.

Holder does not send card-vault contents to Apple or RevenueCat for purchase processing.

See the [Apple Privacy Policy](https://www.apple.com/legal/privacy/) and [RevenueCat Privacy Policy](https://www.revenuecat.com/privacy/).

## Widgets

If you add a Holder widget, the app shares the card label, card type, network, card identifier, and last four digits with its local App Group so the widget can display them. Widgets do not receive the full card number, security code, or expiration date.

Information displayed by Home Screen, Lock Screen, Control Center, or other system surfaces follows your device and notification-visibility settings.

## Copying and sharing

Copying or sharing card details is an action you choose. Standard sharing omits the security code. Including a security code requires explicit action and recent device-owner authentication.

Once information is copied to the system clipboard or sent to another app or person, its retention and use are controlled by the operating system, destination, or recipient. Holder does not automatically clear the system clipboard.

## Face ID, Touch ID, and device authentication

Face ID, Touch ID, and device-passcode checks are handled by Apple. Holder receives only the authentication result and never receives or stores your biometric data.

## Data retention and deletion

Card records and optional images remain until you delete them or remove the app data, subject to Apple Keychain, iCloud synchronization, and backup behavior. Analytics, diagnostic, and purchase records are retained by PostHog, Sentry, RevenueCat, and Apple according to their policies.

Holder does not currently provide a server account or a server-side card-data deletion process because Holder does not operate a server that stores your card vault.

## Security

Holder uses Apple platform security features and limits the card information sent to service providers. No storage or transmission method is completely secure, and security also depends on your device passcode, Apple Account, iCloud settings, and how you copy or share information.

## Children

Holder is not directed to children. If you believe a child has provided information through Holder in a way that requires action, contact me using the address below.

## Changes to this policy

I may update this policy when Holder's features, providers, or legal requirements change. The latest published version will show its effective date.

## Contact

For privacy questions or requests, email [sayhi@swiftlysingh.com](mailto:sayhi@swiftlysingh.com).
