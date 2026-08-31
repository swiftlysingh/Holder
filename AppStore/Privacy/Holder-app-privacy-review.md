# Holder App Privacy review checklist

Evidence date: August 26, 2026

This is a review artifact, not a completed App Store Connect declaration. Current ASC App Privacy answers could not be read because the web-only workflow requires an Apple Account session. Do not publish answers from this file without owner review.

## Confirm before submission

- Reconcile the published privacy policy with `Holder-privacy-policy-draft.md`.
- Confirm PostHog, Sentry, RevenueCat, and SinghDevKit versions in the final archive.
- Confirm the final archive contains each dependency privacy manifest.
- Review RevenueCat's current default collection of anonymous identifiers, IDFV or IDFA when available, and IP information.
- Decide the correct ASC data-type, linked-data, tracking, and purpose answers for analytics, diagnostics, device identifiers, and purchase history.
- Confirm card numbers, names, expiration dates, security codes, OCR text, and card images are not declared as collected by Holder or its providers because no provider upload path was found.
- Confirm optional iCloud Keychain and iCloud Documents behavior is described in the public policy even though Apple-operated synchronization is not Holder analytics collection.
- Verify widget disclosure covers card labels and last four digits on system surfaces.
- Verify clipboard and sharing disclosure covers downstream retention.
- Replace the public Google Doc before submission and update the policy's effective date.
- Pull the ASC declaration after an explicitly coordinated Apple Account login, then compare it with the final archive and policy.

## Code-backed provider summary

| Provider | Observed categories | Purpose | Card contents sent |
| --- | --- | --- | --- |
| PostHog | Product interaction, other usage data, pseudonymous installation context, aggregated performance summaries | Analytics and reliability | No |
| Sentry | Crash, hang, performance, and sanitized diagnostic data | App functionality and reliability | No |
| RevenueCat | Purchase history, product and subscription state, anonymous customer and device context | Purchases and app functionality | No |
| Apple | Keychain and optional iCloud synchronization, LocalAuthentication, App Store purchases | App functionality and platform services | Card data may sync through user-controlled Apple services; Holder does not operate the receiving server |

## Known evidence limits

- The public policy is currently stale and generic.
- The current ASC App Privacy declaration is unverified.
- Provider retention periods and user-request workflows were not established from repository code.
- Dependency manifests support the audit but do not prove the final ASC answers.
- No app-owned `PrivacyInfo.xcprivacy` file was found. The final archive must be inspected before treating dependency manifests as complete evidence.
