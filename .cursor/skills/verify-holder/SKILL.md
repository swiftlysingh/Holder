---
name: verify-holder
description: Drive Holder, the SwiftUI card vault for iOS and macOS, the way a user does and capture proof. On Linux it drives the real card-scan pipeline (OCR frames in, filled add-card editor out) and fails closed for everything that needs the app. On a Mac it adds simulator launch recipes. Use when a change touches card scanning, card fields, or any Holder user flow and you must prove behavior, not just compile.
---

# Verify Holder

Holder's user surface is the iOS and macOS app (`cards.xcodeproj`, scheme `cards`, product `Holder.app`). It needs Xcode. On a host without Xcode, the only real surface is the scan pipeline core: `cards/ScanView/CardCandidateEngine.swift`, `cards/ScanView/CardScanSession.swift`, and `cards/Model/CardData.swift`. The helper compiles those files in place on Linux, with no copies, and feeds them the same OCR text items that VisionKit hands the app.

Feature recipes live in [`features/README.md`](features/README.md). Read it before you drive anything.

Helper: `.cursor/skills/verify-holder/scripts/verify-holder.sh`. Run it from anywhere inside the checkout. Below, `$V` is that path.

## Fail closed

- Never report an app feature as verified from a Linux run. Run `$V app-preflight` first. Without Xcode it prints `RESULT fail-closed surface=app reason=not-macos|no-xcodebuild|no-simctl` and exits 1. Report that line verbatim and stop that feature.
- A core run proves only the scan pipeline from OCR text to editor fields. It does not prove the camera, Vision OCR, the still-photo capture, SwiftUI rendering, Keychain persistence, or the save button.
- Every `RESULT fail-closed` line names the surface and reason. Do not route around one.

## Launch

Core (Linux or macOS with a Swift toolchain):

```bash
V=.cursor/skills/verify-holder/scripts/verify-holder.sh
$V setup-swift        # once per machine; Ubuntu 24.04 x86_64 only
eval "$($V launch | tee /dev/stderr | grep '^export ')"
```

- `setup-swift` installs Swift 6.2.1 into `${HOLDER_SWIFT_TOOLCHAIN:-/tmp/swift-toolchain}` and `libncurses6` through `sudo apt-get`. It is a no-op when `swift` already runs.
- `launch` builds a fresh SwiftPM package under `/tmp/holder-verify/runs/$HOLDER_VERIFY_RUN_ID/`. It symlinks the three real source files, extracts `struct CardScanResult` from `cards/ScanView/CardScanning.swift` and the `String` and `UInt` extensions from `cards/Extensions.swift`, and maps `import CoreGraphics` to Foundation, which defines `CGRect` on Linux.
- Ready means the last two lines are `export HOLDER_VERIFY_RUN_ID=<id>` and `RESULT ready surface=core run=<id> dir=<path>`. The first build takes about 30 seconds.
- Without Swift it prints `RESULT fail-closed surface=core reason=no-swift` and exits 127. A compile error prints the log tail and `reason=build-failed`.
- Set `HOLDER_VERIFY_RUN_ID` before `launch` to pick the id. Relaunching the same id rebuilds in place.

App (macOS only, unverified, no Mac run has executed these yet):

```bash
$V app-preflight
RUN=/tmp/holder-verify/runs/$HOLDER_VERIFY_RUN_ID
SIM=$(xcrun simctl create "holder-verify-$HOLDER_VERIFY_RUN_ID" "iPhone 16")
xcrun simctl boot "$SIM"
xcodebuild -project cards.xcodeproj -scheme cards -configuration Debug \
  -destination "id=$SIM" -derivedDataPath "$RUN/DerivedData" build
xcrun simctl install "$SIM" "$RUN/DerivedData/Build/Products/Debug-iphonesimulator/Holder.app"
xcrun simctl spawn "$SIM" defaults write com.swiftlysingh.cards.debug holder.onboarding.completedRelease -int 203
xcrun simctl spawn "$SIM" defaults write com.swiftlysingh.cards.debug isAuthEnabled -bool false
xcrun simctl launch "$SIM" com.swiftlysingh.cards.debug
```

- Debug bundle id is `com.swiftlysingh.cards.debug`. Display name is `Holder-debug`.
- Onboarding shows until `holder.onboarding.completedRelease` is at least 203. The vault lock shows until `isAuthEnabled` is false. No launch argument skips either one.
- Ready means a simulator screenshot shows the Home list, not `Holder is locked` and not the onboarding cover.
- The repo has no XCUITest target. Taps need a simulator control tool that targets accessibility labels. If you have none, report `fail-closed reason=no-ui-harness`.
- The first Mac run must confirm these commands, fix them in this file, and delete the "unverified" label.

## Doctor

```bash
$V doctor
```

Read-only. Run it first, and again whenever anything looks off. It prints:

- `CORE swift=...` or `swift=missing`.
- `CORE run=<id> binary=fresh|stale|missing`. `stale` means a compiled source, an extracted source, or the driver changed since `launch`. Relaunch.
- `CORE glue=ok checks=10` or one `glue=drift` line per missing call. The driver mirrors the iOS-only glue in `VisionCardScanningEngine.swift` and `CardViewModel.applyScan`. On drift, reread those files and update `scripts/holder-scan/main.swift` before you trust a run.
- The `app-preflight` line.
- `RESULT core=ok|not-drivable app=ok|fail-closed`. Exit 0 only when the core is drivable.

## Drive

```bash
$V drive scan visa-split-lines
$V drive scan /path/to/your-fixture.json
```

A fixture is the OCR boundary plus the expected editor. `fixtures/` holds the shipped ones. The scan-card feature file documents the format and lists them.

The driver runs the app's per-frame order. `CardCandidateEngine.observe`, then `CardScanAttempt.record`, then `TemporalPANVoter.record` with the app defaults (8-frame window, 2 votes). After the vote it ignores later frames. Then it runs the still-photo merge, or the no-still fallback when the fixture has no `still`. Then `CardScanSession.apply` onto the editor card. Output lines:

- `FRAME n` shows each frame's last four digits, network, expiry, and name, or `ignored reason=verifying`.
- `UPDATE candidate|scanning|verified|retryableFailure|none` matches the `CardScanUpdate` the scanner UI would get.
- `EDITOR` shows the add-card fields after the scan lands. The CVV is masked.
- `ASSERT <field> expected=... actual=... ok|FAIL`, then `RESULT pass|fail`.

Exit 0 means pass, 1 means an assertion failed, and 2 means a bad fixture or usage error.

## Evidence

- Each `drive` writes `/tmp/holder-verify/evidence/<run-id>/scan-<fixture>-<HHMMSS>/` with `command.txt`, `fixture.json`, `stdout.txt`, `stderr.txt`, `exit-code.txt`, and `provenance.txt`. Provenance holds the git HEAD, the count of dirty files under `cards/`, and the Swift version. Override the root with `HOLDER_VERIFY_EVIDENCE`.
- A proof is the `FRAME` and `UPDATE` trail, which is the action, plus the `EDITOR` line, which is the resulting state, plus the exit code. A bare `RESULT pass` is not proof.
- Prove a change in both directions. Drive a fixture that must pass, and one that must not fill the form, such as `single-frame` or `luhn-invalid`.
- Fixtures use published test numbers only, such as `4111 1111 1111 1111` and `3782 822463 10005`. Never put a real card in a fixture or in evidence.
- App proof on a Mac is a `xcrun simctl io "$SIM" screenshot <path>` before and after each action, stored in the same evidence directory.

## Cleanup

```bash
$V cleanup
```

- Removes `/tmp/holder-verify/runs/$HOLDER_VERIFY_RUN_ID` only. It prints `EVIDENCE kept=<dir> files=<n>`. Confirm that line before you report.
- Core runs start no long-lived process, so there is nothing to kill.
- On a Mac, also run `xcrun simctl shutdown "$SIM"` and `xcrun simctl delete "$SIM"` for the simulator you created. Never delete or erase a simulator you did not create.

## Isolation

- Each run id has its own package, build directory, and evidence directory. Parallel core runs do not share state.
- On a Mac, always create a dedicated simulator. Never drive the user's booted simulator or a device. Holder stores cards as synchronizable Keychain items, so a simulator signed in to an Apple ID can sync test cards to a real account.

## Helpers

- `scripts/verify-holder.sh` takes `setup-swift`, `launch`, `doctor`, `drive scan <fixture>`, `cleanup`, or `app-preflight`. It reads `HOLDER_VERIFY_RUN_ID`, `HOLDER_VERIFY_ROOT` (default `/tmp/holder-verify`), `HOLDER_VERIFY_EVIDENCE`, and `HOLDER_SWIFT_TOOLCHAIN`.
- `scripts/holder-scan/main.swift` is the driver. `launch` symlinks it into the build, so an edit takes effect on the next `launch`.
- `fixtures/*.json` holds the scan journeys.
- To maintain the feature map as the app changes, use `/maintain-verification-skill`.
