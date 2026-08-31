# Holder 2.3 App Store screenshots

This directory contains Holder's review-ready screenshot set. It uses
real Holder captures wrapped in a shared Koubou marketing layout defined by
`config.yaml` and the HTML templates.

## Store sequence

1. **Your cards. One private place.** Establish what Holder is with the card
   list.
2. **Scan it. Skip the typing.** Show the exact production scanner UI.
3. **Private by design.** Show useful card details while the security code
   remains protected.

The scan flow is:

`Cards → Add Card → Scan → Review detected details → Save → Cards`

Manual entry remains available when camera access is unavailable or a field
cannot be detected confidently.

## Generate the set

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

The localized iPhone sets use the same English Debug captures with localized
marketing copy. Generate them with `config.fr-FR.yaml` and `config.de-DE.yaml`;
their outputs live under `output/fr-FR/` and `output/de-DE/`.

## Recapture workflow

1. Use a dedicated iPhone 17 Pro Max simulator with Holder's Debug
   configuration for the home and detail captures.
2. Set a consistent locale, appearance, and status bar. The current en-US set
   uses 9:41, full signal, Wi-Fi, and a charged battery.
3. Reset the simulator before the final pass, including its Keychain data, then
   complete first-launch onboarding. Holder's existing Debug fixtures seed the
   M. C. Lovin sample cards into an empty vault.
4. Capture `home.png`, then open the sample Everyday Card for
   `card-details.png`.
5. Capture the unchanged scanner UI on an iPhone at its default half-height
   presentation, using the explicit Debug screenshot fixture for the simulator
   camera feed. Launch the Debug build with
   `--holder-screenshot-scanner-fixture`; Release and Beta builds do not compile
   the fixture. Crop from the scanner sheet's top edge to the bottom of the
   screen and save it as `scanner-sheet.png`. Do not retain any part of the
   vault behind the sheet.
6. Keep source captures under `captures/<locale>/`. Do not add marketing copy,
   pointers, device frames, notifications, or real card data to these files.
7. Update `config.yaml` for screenshot order, copy, templates, and source
   assets. Keep marketing layout and styling in `templates/`.
8. Regenerate the set and inspect every output at full size and as gallery
   thumbnails.
9. Confirm every layout report has an empty `overlaps` array and every final
   PNG is 1320 × 2868 before upload.

Never edit files under `output/` by hand. Change the capture, template, or
configuration and regenerate them.

## Source asset rules

All three en-US assets are real Holder UI captures. The scanner asset is a
pixel-preserving crop of the production scanner sheet with the explicit Debug
screenshot fixture beneath its unchanged frame and controls. Its source vault
area is excluded completely, so no personal card names or digits are present.
The home and detail captures use only Debug sample cards and never use
production or personal vault data.

Do not use screenshots downloaded from App Store Connect because those already
include marketing artwork and can create a nested, distorted presentation.

## Final checklist

- The first screenshot makes Holder's purpose obvious without its subtitle.
- Each later screenshot communicates one distinct benefit.
- All claims match behavior in the submitted build.
- Card names and numbers are synthetic and clearly presented as samples.
- Expiration dates are in the future, card values are documented public test
  fixtures, and no real or personal credentials are shown.
- The security code remains protected in the detail screenshot.
- Text remains legible at App Store search-result size.
- The generated set uses the approved order from `config.yaml`.
- Upload happens only after explicit authorization and a final visual review.

## Deferred

- Widget artwork
