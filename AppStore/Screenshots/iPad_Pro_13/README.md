# Holder 2.3 iPad screenshots

This is the reproducible iPad-only Koubou configuration for the App Store
`APP_IPAD_PRO_3GEN_129` slot. It renders the approved 2048 × 2732 portrait
size (`iPadPro12_9`) to `../output/iPad_Pro_13_-_Portrait/`.

The shared iPhone `config.yaml` and base templates stay unchanged. This folder
contains only the two iPad-specific layout copies needed for the wider canvas:

- `01_cards_together` moves the device panel down so the subtitle stays clear.
- `02_scan_card` uses a centered, portrait-shaped panel. It keeps the exact
  privacy-safe `scanner-sheet.png` crop with `object-fit: contain`, without
  showing any vault content behind the scanner.

From `AppStore/Screenshots`:

```sh
export PLAYWRIGHT_BROWSERS_PATH="$PWD/.playwright-browsers"
.venv/bin/kou generate iPad_Pro_13/config.yaml --parallel-workers 3 --output json
```

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
