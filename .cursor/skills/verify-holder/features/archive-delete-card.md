# Archive and delete a card

Archive and delete let a user hide a card they rarely use without losing it, bring it back later, or remove it for good after confirming and authenticating. App only. No Linux path exists, so a host without Xcode reports this feature as fail-closed.

## Sub-features

- `archive` moves a card from its Home section to Archived Cards. No authentication.
- `unarchive` returns a card to its Home section. No authentication.
- `delete-confirm` asks `Delete this card?` before anything happens.
- `delete-auth` deletes only after authentication succeeds.

## How to get to it (user POV)

- On Home, swipe a card row left for `Delete` and `Archive`, or long-press it for the same actions (`cards/Home/HomeView.swift:53-77`).
- On Home, tap `View Archived Cards (<count>)` to open `Archived Cards` (`cards/Home/HomeView.swift:83-91`, `cards/Home/ArchivedCardsView.swift:57`).
- In Archived Cards, swipe or long-press for `Delete` and `Unarchive` (`cards/Home/ArchivedCardsView.swift:29-53`).

## Driving it with verify-holder.sh

Preconditions:

- `$V app-preflight` prints `RESULT ready surface=app`. Otherwise report its `fail-closed` line and stop.
- Baseline app preconditions from the README hold. Home shows at least one card and no `View Archived Cards` link.

- **Archive.** Long-press a card row and choose `Archive`. The row leaves Home and the link `View Archived Cards (1)` appears.
- **Unarchive.** Tap the link, then long-press the card and choose `Unarchive`. The list shows `No Archived Cards`. Go back, and the card is in its type section again.
- **Delete, cancelled.** Long-press the card and choose `Delete`. The dialog `Delete this card?` shows `Delete Card` and `This cannot be undone.` (`cards/Home/HomeView.swift:192-205`). Tap `Delete Card`, then cancel the authentication prompt. The card stays.
- **Delete, confirmed.** Repeat and pass authentication with `xcrun simctl spawn "$SIM" notifyutil -p com.apple.BiometricKit_Sim.fingerTouch.match` after enrolling biometrics, or enter the simulator passcode. The row disappears.
- **Persistence.** Terminate and relaunch the app. Archived state and the deletion hold.
- **Proof.** Take a screenshot after each step and after relaunch.

## Gotchas

- Unverified. No Mac run has executed this recipe, including the biometric `notifyutil` command.
- Full swipe is off (`allowsFullSwipe` is false). A swipe only reveals the buttons.
- The macOS menu bar lists active cards only and has no archive or delete action (`cards/macOS/MenuBarView.swift:241-243`).
- Delete removes the Keychain item and the card image (`cards/Model/CardDataStore.swift:336-346`). On the Debug build, deleting every card does not reseed once `debugFixturesInitialized` is true.
- Archiving also drops the card from the widget snapshot `widgetAvailableCards` in app group `group.com.swiftlysingh.cards` (`cards/Model/CardDataStore.swift:507-524`).
