# Holder screenshot concepts

This directory is a review-sized Koubou integration for exploring Holder's App
Store screenshot direction without committing us to a final capture,
localization, or upload workflow yet.

The three checked-in outputs use Holder's future semantic palette and a shared
visual language while telling distinct parts of the product story. Each
screenshot points to its own HTML template in `config.yaml`.

## Store sequence

1. **Your cards. One private place.** Establish what Holder is with the card
   list.
2. **Scan it. Skip the typing.** Introduce scanning as the differentiator after
   the product is understood.
3. **Private by design.** Combine the card-detail utility with Holder's
   Keychain and Face ID privacy story.

The scan flow represented by the second concept is:

`Cards → Add card → Scan card → Review detected details → Save → Cards`

Manual entry remains the fallback when camera access is unavailable or a field
cannot be detected confidently.

## Generate the samples

From this directory:

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/kou setup-html
.venv/bin/kou generate config.yaml
```

Koubou writes the PNGs and layout reports to `output/`.

## Source asset rule

`captures/` contains raw simulator screenshots only. The current concepts use
those real captures for the card list and card details. The scanner is
illustrative until its production UI is ready. Final App Store artwork should
replace all three states with representative captures from the redesigned app.

Do not use screenshots downloaded from App Store Connect because those already
include marketing artwork and can create a nested, distorted presentation.

The current `en-US` assets are real iPhone 17 Pro Max Debug captures of the
card list and a card detail. The cards come from Holder's compile-time Debug
fixture. No production or personal card data is present.

## Deliberately deferred

- Automated simulator navigation and capture
- Representative redesigned app captures and a real widget capture
- Localization and copy fitting
- iPad and alternate iPhone sizes
- App Store Connect validation and upload

Those decisions can follow after the visual direction is approved.
