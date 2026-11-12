# Add a card manually

Add a card manually lets a user type a card's name, number, expiry, security code, and description, pick a card type, and save. The card then appears on Home under its type and survives a relaunch. App only. No Linux path exists, so a host without Xcode reports this feature as fail-closed.

## Sub-features

- `add-open` opens the add sheet from Home or onboarding.
- `add-fields` accepts the five text fields and the network and type pickers.
- `add-gate` keeps save disabled until a type is picked, and for `Credit` or `Debit` until the number is non-empty.
- `add-save` saves and shows the card on Home.
- `add-persist` shows the card again after a relaunch.

## How to get to it (user POV)

- On iOS Home, tap the plus button labeled `Add Card`, then `Having trouble? Enter manually` after 3 seconds (`cards/Home/HomeView.swift:285-309`, `cards/ScanView/CardScannerView.swift:76-88`).
- In onboarding step 2, tap `Enter Card Details` when scanning is unavailable (`cards/Onboarding/HolderOnboarding.swift:353-372`).
- On macOS, choose the `Add Card` toolbar item. The manual form opens directly (`cards/Home/HomeView.swift:110-115`).

## Driving it with verify-holder.sh

Preconditions:

- `$V app-preflight` prints `RESULT ready surface=app`. Otherwise report its `fail-closed` line and stop.
- Baseline app preconditions from the README hold. Home is visible.
- No card has the description `Verify Manual`.

- **Open the form.** Tap `Add Card` on Home, then `manualCardEntryButton`. The header `Add a Card` appears with text fields whose prompts are `Name`, `Number`, `Expiration`, `Security Code`, and `Description` (`cards/CardView/CardView.swift:153-161`, `cards/CardView/CardView.swift:312-317`).
- **Check the gate.** Before you pick a type, the button with identifier `addCardButton` is disabled.
- **Enter content.** Type `Jane Doe`, `4111111111111111`, `12/28`, `123`, and `Verify Manual`. Pick `Credit` in the `Card Type` picker (`cards/CardView/CardView.swift:372-388`). `addCardButton` becomes enabled.
- **Save.** Tap `addCardButton`. The sheet closes. Home shows a `Credit` row titled `Verify Manual` with subtitle `•••• 1111` (`cards/Home/HomeView.swift:415-431`).
- **Persistence.** Run `xcrun simctl terminate "$SIM" com.swiftlysingh.cards.debug`, then launch again. The `Verify Manual` row is still there.
- **Proof.** Take `xcrun simctl io "$SIM" screenshot` after save and after relaunch.

## Gotchas

- Unverified. No Mac run has executed this recipe.
- macOS saves with a toolbar `Done` button, not `addCardButton` (`cards/CardView/CardView.swift:505-514`).
- A failed save keeps the sheet open with the typed values. A closed sheet alone is not proof. Look for the Home row.
- Cards persist as synchronizable Keychain items keyed by card UUID under service `com.swiftlysingh.cards.debug` (`cards/Model/CardDataStore.swift:415-469`). There is no file to read back. Relaunch is the second view.
- Delete `Verify Manual` during cleanup, or delete the simulator.
