# Scan a card

Scan a card lets a user point the iPhone camera at a payment card and get the add-card editor filled with the formatted number, network, expiry, and cardholder name. Fields the user already typed, such as description, type, and security code, stay untouched. A misread number must leave the form alone and keep scanning.

## Sub-features

- `scan-reconstruct` joins a number split across OCR lines or misread with look-alike letters (`l` for `1`) into one Luhn-valid number.
- `scan-vote` needs the same number in 2 of the last 8 frames before it calls the number stable.
- `scan-still` checks a still photo after the vote. The still supplies expiry and name. The live number wins.
- `scan-no-still` falls back to the live number and expiry when no still is available. The name is dropped.
- `scan-apply` writes the result onto the editor without wiping user-entered fields.
- `scan-reject` leaves the editor empty for a single frame or a Luhn-invalid number.

## How to get to it (user POV)

- On iOS Home, tap the plus button labeled `Add Card`. The sheet opens the scanner because Home always passes `.scanner` (`cards/Home/HomeView.swift:286-290`).
- In onboarding step 2, tap `Scan a Card`. It appears only when the device supports DataScanner (`cards/Onboarding/HolderOnboarding.swift:353-361`).
- In the scanner, `Having trouble? Enter manually` (identifier `manualCardEntryButton`) appears after 3 seconds and opens the empty form (`cards/ScanView/CardScannerView.swift:76-88`).
- macOS has no scanner. Add Card opens the manual form (`cards/CardView/CardView.swift:62-70`).

## Driving it with verify-holder.sh

Preconditions:

- Baseline core preconditions from the README hold.
- `doctor` prints `glue=ok`.

Fixture format. `now` is an ISO 8601 date that pins expiry validation. `editor` holds optional pre-typed fields, which are `number`, `cvv`, `expiration`, `name`, `description`, and `type` (`Credit`, `Debit`, or `Other`). `frames` is a list of frames, and each frame is a list of OCR items with `text`, optional `candidates`, and optional `box` in Vision coordinates (`x`, `y`, `width`, `height`, normalized, origin lower-left). `still` is an optional item list. `expect.verified` is a boolean. `expect.editor` maps field names to exact expected strings. Valid field names are `number`, `network`, `expiration`, `name`, `description`, `type`, and `cvv`.

- **Split and misread number fills the form.** Run `$V drive scan visa-split-lines`. You see `UPDATE candidate lastFour=1111 network=Visa` twice, `UPDATE scanning`, `FRAME 3 ignored reason=verifying`, `UPDATE verified ... name="JANE DOE"`, and `EDITOR number="4111 1111 1111 1111" network="Visa" expiration="12/28" name="JANE DOE" description="Travel card" type="Debit" cvv="•••"`. Exit 0.
- **15-digit number without a still.** Run `$V drive scan amex-no-still`. You see `STILL unavailable` and `EDITOR number="3782 822463 10005" network="Amex" expiration="09/27" name=""`. The name stays empty even though every frame read `ALEX MORGAN`. Exit 0.
- **One frame is not enough.** Run `$V drive scan single-frame`. You see one `UPDATE candidate`, then `UPDATE none reason=no-stable-pan`, and an empty `EDITOR`. Exit 0.
- **Misread number is rejected.** Run `$V drive scan luhn-invalid`. The number line reads `4111 1111 1111 1112` and the expiry line reads `12/28`. The expected result is `UPDATE none` and an empty editor. At `2170cc6` this journey fails with exit 1. See Gotchas.
- **Proof.** After each run, the `EVIDENCE dir=` line names the folder. Keep `stdout.txt` and `exit-code.txt`. After `$V cleanup`, the `EVIDENCE kept=` line must still list them.
- **Mac supplement (unverified).** Run `xcodebuild test -project cards.xcodeproj -scheme cards -destination "id=$SIM" -only-testing:cardsTests/CardCandidateEngineTests -only-testing:cardsTests/CardScanSessionTests`. These are unit tests, not a user path. The live camera path needs a physical iPhone. `--holder-screenshot-scanner-fixture` only draws a card and never fills the form (`cards/ScanView/VisionCardScanningEngine.swift:475-487`).

## Gotchas

- At `2170cc6`, `luhn-invalid` fails. The joined-text fallback at `cards/ScanView/CardCandidateEngine.swift:311` concatenates every OCR line. It turns `4111111111111112` plus the expiry digits `1228` into the 17-digit Luhn-valid prefix `41111111111111121`, and the editor shows `4111 1111 1111 1112 1` as a Visa. Without the expiry line, the same number is rejected. Do not edit the fixture to pass. It passes when the engine is fixed.
- The driver mirrors the private, iOS-only glue in `VisionCardScanningEngine.swift` (`scannerHostDidRecognize`, `verifyCurrentCandidate`, `merge(still:livePAN:)`). `doctor` greps for each mirrored call. A `glue=drift` line means the mirror may be wrong.
- The still path skips Vision's perspective correction and `.accurate` OCR. The fixture's `still` items stand in for that OCR output.
- The app calls `observe` with the current date. The driver uses the fixture's `now`, so a run is repeatable. An expiry more than 10 years after `now`, or in the past, is dropped (`cards/ScanView/CardCandidateEngine.swift:157-181`).
- A scan never selects the card type. On a new card, `type` stays `Credit` in the model, but the app's save button stays disabled until the user picks a type (`cards/CardView/CardViewModel.swift:46-49`).
- On a simulator without a camera, the scanner shows alert `Scanner`, and `OK` dismisses the whole add sheet. Camera permission denial falls through to the form instead.
