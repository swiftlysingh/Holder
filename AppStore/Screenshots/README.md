# Holder screenshot concepts

This directory is a review-sized Koubou integration. It proves that Holder's
real app UI can be composed into App Store-sized artwork without committing us
to a final capture, localization, or upload workflow yet.

The three checked-in outputs intentionally share colors and typography while
using different layouts. Koubou does not force every screenshot to look the
same: each screenshot points to its own HTML template in `config.yaml`.

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

`captures/` contains raw simulator screenshots only. Do not use screenshots
downloaded from App Store Connect here because those already include marketing
artwork and can create a nested, distorted device presentation.

The current `en-US` assets are real iPhone 17 Pro Max Debug captures of the
card list, a card detail, and Settings. The cards come from Holder's
compile-time Debug fixture. No production or personal card data is present.

## Deliberately deferred

- Automated simulator navigation and capture
- Additional app states and the final screenshot story
- Localization and copy fitting
- iPad and alternate iPhone sizes
- App Store Connect validation and upload

Those decisions can follow after the visual direction is approved.
