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
export PLAYWRIGHT_BROWSERS_PATH="$PWD/.playwright-browsers"
.venv/bin/kou setup-html
.venv/bin/kou generate config.yaml --output json
```

Browser setup is only required once. Koubou writes the PNGs and layout reports
to `output/`.

## Recapture and update workflow

1. Use one dedicated screenshot simulator and the app's Debug configuration.
2. Reset that simulator before the final capture pass. Holder stores the Debug
   fixtures in Keychain, which can survive deleting and reinstalling the app.
3. Launch once with an empty Keychain so the fixtures in
   `cards/Model/CardDataStore.swift` seed cleanly.
4. Navigate to each approved state and capture raw app UI without a device
   frame, marketing copy, pointer, debug overlay, notification, or real data.
5. Replace the corresponding PNG under `captures/<locale>/`. Keep every final
   capture on the same device, orientation, appearance, and status-bar state.
6. Update `config.yaml` for screenshot order, copy, templates, and source
   assets. Keep marketing layout and styling in `templates/`.
7. Run the generation command and visually inspect every output at full size
   and as a small gallery thumbnail.
8. Check every layout report for annotated overlaps and confirm every final PNG
   is 1320 x 2868 before committing it.

Never edit files under `output/` by hand. Change the capture, template, or
configuration and regenerate them.

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

## Final capture checklist

- The first screenshot makes Holder's purpose obvious without reading its
  subtitle.
- Each later screenshot communicates one distinct benefit.
- All claims match behavior in the submitted build.
- Card names and numbers are synthetic, globally neutral, and consistently
  masked where appropriate.
- Expiration dates are in the future and no reusable-looking credentials or
  personal data are shown.
- The scanner is captured from the production flow, not the illustrative
  concept currently checked in.
- Text remains legible at App Store search-result size.
- The generated set uses the approved order from `config.yaml`.
- App Store Connect upload remains a separate, explicitly authorized action.

## Deliberately deferred

- Automated simulator navigation and capture
- Representative redesigned app captures and a real widget capture
- Localization and copy fitting
- iPad and alternate iPhone sizes
- App Store Connect validation and upload

Those decisions can follow after the visual direction is approved.
