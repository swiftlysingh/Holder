# Holder 2.3 iPad screenshots

This is the reproducible iPad-only Koubou configuration for the App Store
`APP_IPAD_PRO_3GEN_129` slot. It renders the approved 2048 × 2732 portrait
size (`iPadPro12_9`) to `../output/iPad_Pro_13_-_Portrait/`.

The shared iPhone `config.yaml` and base templates stay unchanged. This folder
contains only the two iPad-specific layout copies needed for the wider canvas:

- `01_cards_together` moves the device panel down so the subtitle stays clear.
- `02_scan_card` uses a centered, portrait-shaped panel. Its source is the
  native iPad scanner UI captured from the Debug build with an explicit,
  screenshot-only fictional camera feed. The production scanner sheet, frame,
  controls, and copy are unchanged; the fixture only replaces the simulator's
  unavailable camera content. The seeded fictional vault remains visible behind
  the sheet, and the approved iPhone `scanner-sheet.png` is never reused here.

The iPad sources are real captures from an iPad Pro 13-inch simulator:
`../captures/en-US/ipad-home.png`, `../captures/en-US/ipad-scanner-fixture.png`,
and `../captures/en-US/ipad-card-details.png`. They use only Holder's fictional
Debug fixtures. The home, scanner, and details captures show the native iPad
split view; the detail capture was taken after the sensitive-access window
expired so the security code remains protected.

From `AppStore/Screenshots`:

```sh
export PLAYWRIGHT_BROWSERS_PATH="$PWD/.playwright-browsers"
.venv/bin/kou generate iPad_Pro_13/config.yaml --parallel-workers 3 --output json
```

The French and German iPad variants use `config.fr-FR.yaml` and
`config.de-DE.yaml`; their outputs live under `output/fr-FR/` and
`output/de-DE/`.

Stage and upload only the three PNGs. The generated `.layout.json` reports are
layout QA artifacts and make `asc screenshots validate` fail if they share the
upload directory:

```sh
stage_dir="$(mktemp -d /private/tmp/holder-ipad-upload.XXXXXX)"
cp output/iPad_Pro_13_-_Portrait/*.png "$stage_dir"/

asc screenshots validate \
  --path "$stage_dir" \
  --device-type IPAD_PRO_3GEN_129 \
  --output table
```
