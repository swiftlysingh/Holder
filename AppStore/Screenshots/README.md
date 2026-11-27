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

## iPhone Duo sets

App Store Connect has two iPhone Duo slots: the outer display (1398 × 2034
portrait) and the inner display (2853 × 2007 landscape). Apple requires them
from April 2027 for apps built with the iOS 27.1 SDK or later, and uploading
them adds the "made for iPhone Duo" badge to the product page.

- `iPhone_Duo_Outer/` renders the outer set to
  `output/iPhone_Duo_Outer_-_Portrait/`.
- `iPhone_Duo_Inner/` renders the inner set to
  `output/iPhone_Duo_Inner_-_Landscape/`. The inner display opens like a book,
  so the set is landscape, with the copy on the left and the app on the right.

Both use the same sequence and copy as the iPhone set, in en-US, fr-FR and
de-DE. iPhone Duo has Touch ID instead of Face ID, so the third subtitle says
Touch ID.

The captures came from an iPhone Duo simulator (iOS 27.1) running the Debug
build with its sample cards and `--holder-screenshot-scanner-fixture`:

- `duo-outer-*.png` with the phone closed. `duo-outer-scanner-sheet.png` is
  cropped from the sheet's top edge, and everything outside the sheet's
  rounded corners is filled black so no part of the vault shows.
- `duo-inner-*.png` with the phone fully open. As in the iPad set, the scanner
  sheet sits over the fictional vault.

From this directory:

```sh
export PLAYWRIGHT_BROWSERS_PATH="$PWD/.playwright-browsers"
for set in iPhone_Duo_Outer iPhone_Duo_Inner; do
  for config in config.yaml config.fr-FR.yaml config.de-DE.yaml; do
    .venv/bin/kou generate "$set/$config" --parallel-workers 3 --output json
  done
done
```

Render on a Mac so the templates get SF Pro. As with the iPad set, upload only
the PNGs, not the `.layout.json` reports.

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

## Product page test

`config.yaml` remains the control. `config.ppo-copy-first.yaml` is a separate
English iPhone treatment, generated with Koubou 0.20.0 and its
**iPhone 17 Pro Max - Silver - Portrait** device frame. All three slides use
`frame: true`; the template places Koubou's framed capture instead of drawing
a CSS phone shell. No treatment screenshots have been uploaded to App Store
Connect.

1. **Your card number, ready to copy.** Everyday Card with Number showing
   Copied! and the security code still locked. Supporting text: Saved details,
   even without internet.
2. **Scan it. Skip the typing.** Full phone with the Debug scanner fixture,
   including the visible Enter card manually action.
3. **Your cards. One private place.** Updated home screen with the Holder
   title and Credit, Debit, and Other section labels. The dedicated privacy
   slide is omitted in this treatment.

Generate it from this directory after the HTML renderer setup above:

```sh
PLAYWRIGHT_BROWSERS_PATH="$PWD/.playwright-browsers" \
  .venv/bin/kou generate config.ppo-copy-first.yaml --output json
```

The raw sources are in `captures/en-US/2.6/`: `home.png`, `scanner.png`, and
`card-details-copied.png`. They are real captures from Holder's Debug build,
using only its sample vault and explicit scanner fixture. All share the same
9:41, full-signal, Wi-Fi, and charging status bar. The scanner source is now a
full-screen capture, not the older sheet-only crop. The copied-number capture
keeps the security code protected; its card fixture uses `4242…` and expiry
09/29. No production app behavior is changed by these screenshot files.

Templates live in `templates/framed/` and share `framed.css`. The relative
`app-icon.png` symlink points to the existing app icon inside this repository.
The scanner phone is smaller than the other two so the entire sheet and
manual-entry action stay visible. Its container allows the drop shadow to
extend naturally instead of clipping it to a rectangle. Slides one and three
intentionally continue past the bottom canvas edge.

Output goes to
`output/ppo-copy-first/iPhone_17_Pro_Max_-_Silver_-_Portrait/`.
All three final PNGs are 1320 × 2868, and all three layout reports have empty
`overlaps` arrays. Review covered the full-size renders and gallery-sized
thumbnails, including the frame, status bar, locked security code, headline
spacing, and scanner shadow. The former frameless treatment assets have been
removed.

This is an English iPhone treatment only. iPad, Mac, French, and German artwork
are not changed. Private keyword research, analytics, and store metadata are
not part of this screenshot PR. Upload and any product-page experiment remain
separate actions.

## Deferred

- Widget artwork
