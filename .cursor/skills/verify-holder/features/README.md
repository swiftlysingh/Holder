# Holder verification map

This directory is the maintained source for verifying Holder's user-facing behavior. Read this index, then use the matching feature file as the recipe. Handles and strings cite source at `2170cc6`. Recheck a cited line when a run disagrees with it.

## Baseline preconditions

Core (scan pipeline, Linux or macOS):

- `swift --version` reports 6.x. If it does not, run `verify-holder.sh setup-swift`.
- `verify-holder.sh launch` ended with `RESULT ready surface=core`, and `HOLDER_VERIFY_RUN_ID` is exported.
- `verify-holder.sh doctor` reports `binary=fresh` and `glue=ok`.

App (macOS with Xcode only, unverified):

- `verify-holder.sh app-preflight` reports `RESULT ready surface=app`.
- A dedicated simulator named `holder-verify-<run-id>` runs the Debug build `com.swiftlysingh.cards.debug`.
- `holder.onboarding.completedRelease` is 203 or more and `isAuthEnabled` is false, so neither onboarding (`cards/Onboarding/HolderOnboarding.swift:17-36`) nor the vault lock (`cards/Platform/AuthenticationSession.swift:238`) covers Home.
- On the first load of an empty Keychain, Debug seeds four cards named `M. C. Lovin` (`cards/Model/CardDataStore.swift:193-244`). Expect those rows, or write `debugFixturesInitialized` as true before launch.

## Driving conventions

- Start every recipe from the baseline state.
- Core actions run through `verify-holder.sh drive scan <fixture>`. App actions use accessibility labels and identifiers. Never use coordinates.
- Two controls are labeled `Add Card`. The Home plus button has no identifier. The editor save button has identifier `addCardButton` (`cards/CardView/CardView.swift:163-185`).
- Archive, unarchive, and copying name, number, or expiry need no authentication. Delete and a locked security code do (`cards/Home/HomeView.swift:390-397`, `cards/CardView/CardView.swift:46-49`).

## Proof and skip reporting

- Capture the action and the resulting state. Core proof is the `FRAME`, `UPDATE`, and `EDITOR` lines plus the exit code. App proof is a simulator screenshot before and after the action.
- Mutation proof needs a second view. After an app save, archive, or delete, relaunch the app and screenshot Home again.
- Record the feature ID and entry point with every artifact.
- Report an app feature on a host without Xcode as `fail-closed` with the `app-preflight` line. Never report it as verified through the core path.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph. It then has exactly four H2 sections in this order. `Sub-features`, `How to get to it (user POV)`, `Driving it with <harness>`, and `Gotchas`.

## Features

- [Scan a card](./scan-card.md) covers OCR to filled editor fields, the vote, the still-photo check, and rejection. Core-drivable on Linux. Proven end to end.
- [Add a card manually](./add-card-manually.md) covers the add sheet, field entry, type selection, save, and persistence. App only.
- [Copy card details](./copy-card-details.md) covers tap-to-copy on the detail view and macOS menu bar, and the security-code gate. App only.
- [Archive and delete a card](./archive-delete-card.md) covers archive, unarchive, and authenticated delete from Home and Archived Cards. App only.
