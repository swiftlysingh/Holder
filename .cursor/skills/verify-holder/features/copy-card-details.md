# Copy card details

Copy card details lets a user tap a field on a saved card to put its value on the clipboard, so they can paste it into a checkout form. Name, number, expiry, and description copy at once. The security code needs a recent authentication. App only. No Linux path exists, so a host without Xcode reports this feature as fail-closed.

## Sub-features

- `copy-field` copies a non-empty field and shows `Copied!` for about 1.5 seconds.
- `copy-empty` does nothing for an empty field.
- `copy-cvv-gate` asks for authentication before the security code shows or copies, outside the add flow and the 60-second window after unlock.
- `copy-menubar` copies `Expires`, `CVV`, and `Name` from the macOS menu bar.

## How to get to it (user POV)

- Open a saved card from Home. In view mode, each non-empty field is a button labeled `Copy <heading>`, such as `Copy Number` (`cards/CardView/CardView.swift:277-302`).
- On macOS, tap the number, name, expiry, or CVV on the card preview, or use the form buttons below it (`cards/CardView/CardView.swift:673-729`).
- On macOS with `keepInMenuBar` on, open the `Holder` menu bar item and expand a card row (`cards/macOS/MenuBarView.swift:281-349`).

## Driving it with verify-holder.sh

Preconditions:

- `$V app-preflight` prints `RESULT ready surface=app`. Otherwise report its `fail-closed` line and stop.
- Baseline app preconditions from the README hold. A saved card with a number exists, such as a seeded `M. C. Lovin` card.

- **Copy the number.** Open the card and tap `Copy Number`. The label changes to `Copied Number`. Run `xcrun simctl pbpaste "$SIM"`. Stdout equals the card's number as shown.
- **Locked security code.** On the same card, the security code row is a button labeled `Authenticate to view security code` (`cards/CardView/CardView.swift:213-225`). Tap it. The simulator shows a passcode or biometric prompt with reason `Authenticate to view this card’s security code.` Run `xcrun simctl pbpaste "$SIM"` again. It still shows the number until authentication succeeds.
- **Proof.** Take a screenshot after each tap. Save each `pbpaste` output beside it.

## Gotchas

- Unverified. No Mac run has executed this recipe.
- The Home row is a navigation link, not a copy target (`cards/Home/HomeView.swift:415-436`).
- The CVV reason in `CardView` uses a curly apostrophe. The menu bar reason uses a straight one (`cards/CardView/CardView.swift:549-552`, `cards/macOS/MenuBarView.swift:251-255`). Match the exact string.
- A vault unlock opens a 60-second window where the security code copies without a prompt (`cards/Platform/AuthenticationSession.swift:58-59`, `cards/Platform/AuthenticationSession.swift:140-157`). Turning the lock off does not open that window, so the gate still shows under the baseline.
- `Copied!` disappears after about 1.5 seconds. Screenshot within that time or rely on `pbpaste`.
