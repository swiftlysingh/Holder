# Holder 2.3 ASO review

Evidence date: 2026-08-26

This document is a review artifact. It does not authorize publishing metadata, submitting the release, or creating Apple Ads campaigns.

## Recommendation

Keep the name `Offline Card Vault: Holder` and test the more human subtitle `Your cards, close at hand`.

Use this en-US keyword field:

```text
secure,keychain,biometric,storage,keeper,wallet,credit,debit,membership,loyalty,insurance,organizer
```

It is 99 UTF-8 bytes. Every term is longer than two characters, does not duplicate the proposed name or subtitle, and describes a real Holder use case. `id` was removed because Apple's current metadata reference requires every keyword to be longer than two characters.

Keep scanning in promotional text, screenshots, and the description rather than the keyword field. Generic `scanner` has measurable popularity, but `card scanner` results are dominated by trading-card, business-card, and document-scanner intent.

## Why

- Holder is #1 for `offline card vault` in the US, France, Germany, and the UK in the captured evidence. A final same-day Kickstart refresh reconfirmed #1 in the US, France, and Germany. The title should remain stable.
- US ranks also support `keychain card vault` at #2, `secure card vault` at #4, `biometric card vault` at #3, `offline card storage` at #4, and `offline card keeper` and `offline card wallet` at #7.
- Kickstart captured 76 tracked rows. Of the 39 rows with rank history, 24 moved, entered, or dropped out in the latest visible comparison.
- Apple Ads bulk sweep checked 130 normalized terms across the US, UK, India, Canada, Australia, Germany, and France. A focused gap closure then queried the three standalone proposed-pack tokens `secure`, `keychain`, and `wallet` across the same seven countries, producing the 133 rows in the final ledger. The bulk sweep had 24 of 910 monthly term-country rows and 19 of 910 weekly rows reportable; the focused sweep added seven monthly and seven weekly matched rows for `wallet`, while `secure` and `keychain` remained below reporting coverage. Missing terms are below reporting coverage, not zero demand.
- PostHog's production-like cohort is small and directional. The US has the strongest activation path. India has the strongest repeat-use signal. France is a reasonable localization test. Germany is still an unproven market experiment.

## Storefront decisions

### Defend

- `offline card vault`
- `secure card vault`
- `keychain card vault`
- `biometric card vault`
- `offline card storage`

### Test carefully

- `credit` and `debit`
- `membership`, `loyalty`, `insurance`, and `organizer` as long-tail building blocks
- French and German localized metadata after native-language review

### Keep as conversion copy

- on-device card scanning
- skip typing
- Face ID, Touch ID, and Keychain proof
- offline access and no bank linking

### Reject

- trading cards and TCG
- document scanning
- banking and payments
- rewards optimization
- Apple Wallet pass creation
- barcode checkout
- digital-ID verification

## Final live rank refresh

Kickstart was checked again at 2026-08-26 17:20 IST after the main evidence snapshot. The strongest defend terms remained stable: `offline card vault` was #1 in the US, France, and Germany; `keychain card vault` was #2 in the US; `biometric card vault` was #3; `secure card vault` and `offline card storage` were #4; and `offline card keeper` and `offline card wallet` were #7.

Two volatile rows moved again during the same day. `credit card vault` had improved from #60 to #21 in the captured snapshot and returned #24 in the final refresh. `card holder` had fallen from #27 to #36 and returned #39 in the final refresh. These are rank snapshots, not daily trends or demand measurements. The compact provider response summary is in `Holder-2.3-live-rank-checks.md`.

## Proposed 2.3 copy changes

- Benefit-led en-US description with one concise privacy proof section and the subtitle `Your cards, close at hand`.
- User-approved promotional text preserved unchanged.
- Separate iOS and macOS release notes. The Mac listing does not claim scanning.
- Draft fr-FR and de-DE metadata prepared locally for review. They must not be published without native-language signoff.

## Measurement sequence

1. Freeze the approved metadata and screenshots for 28 days after release.
2. Track keyword positions weekly by storefront, without mixing countries.
3. Use App Store impressions, product-page views, downloads, and conversion once Apple's new analytics report requests finish processing.
4. Use PostHog only for activation quality: new opener to add, save, scan, and seven-day return.
5. Treat fewer than 300 product-page views or 30 downloads as inconclusive for creative decisions.
6. If long-tail terms increase low-intent traffic without activation, remove `membership,loyalty,insurance,organizer` first and retain the 60-byte core pack.

## Evidence limits

- Apple Ads popularity is not organic rank or competition.
- Kickstart difficulty and entry barrier are competition proxies, not search demand.
- Apple's public Search API result count is supply breadth, not search volume.
- App Store analytics requests are configured, but Apple has not generated report instances yet.
- The French and German drafts are model-assisted and have not received human native-speaker signoff.
- The normalized ledger is the durable review artifact. Large raw Kickstart, Apple Ads, and storefront responses remain task-local, so the repository preserves their dated row-level summaries and caveats rather than a replayable provider archive.

## Apple references

- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [App Store localizations](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
