# Screenshot instructions

- Read `README.md` and `config.yaml` before changing screenshot files.
- Treat `config.yaml` as the source of truth for screenshot order, copy,
  templates, and capture assets.
- Use raw captures from the real app for final screenshots. Never nest existing
  App Store artwork inside a new composition.
- Only create illustrative UI when the user explicitly asks for a concept. Mark
  it clearly in the README and pull request, and never present it as a final
  production capture.
- Never use production, personal, financial, or customer data. Use Holder's
  compile-time Debug fixtures and keep every visible date safely in the future.
- Preserve a consistent device, resolution, orientation, appearance, and
  status-bar state across a localized set.
- Make source changes in `captures/`, `templates/`, or `config.yaml`. Never edit
  generated PNGs or layout reports by hand.
- Regenerate all affected outputs, inspect each PNG visually at full and
  thumbnail size, and confirm its layout report has no annotated overlaps.
- Update the README when the approved sequence, source states, or deferred work
  changes.
- Do not upload screenshots or metadata to App Store Connect unless the user
  explicitly authorizes that external action.
