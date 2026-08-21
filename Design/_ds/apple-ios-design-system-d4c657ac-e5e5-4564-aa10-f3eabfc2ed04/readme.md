# Apple iOS Design System

A design system modeling **Apple's** product-marketing and iOS product visual language: photography-first, near-invisible UI chrome, a single blue interactive accent, and SF Pro typography. Built for prototyping Apple-style interfaces and assets — not an official Apple deliverable.

## Sources

- `uploads/DESIGN-apple.md` — a structured visual analysis of apple.com (homepage, iPhone buy page, environment page, store, accessories) covering color, type, spacing, elevation, shape, and component specs. This is the primary source of truth for every color/type/spacing/radius token in this system.
- [Orange-OpenSource/ouds-ios-design-system-toolbox](https://github.com/Orange-OpenSource/ouds-ios-design-system-toolbox) — Orange's open-source iOS design-system demo app. **Not an Apple property** — its own brand colors were not used. It was read only for its **component inventory and native iOS structure** (which primitive families a real iOS toolbox ships: Button, Checkbox, Radio, Switch, Chip, TextInput/TextArea/PasswordInput/PinCodeInput, Badge, Tag, Divider, Alert, Link, TabBar, ToolBar, BulletList) — that inventory shaped which components this system builds, restyled entirely in Apple's own tokens. Explore the repo directly (and its companion [ouds-ios](https://github.com/Orange-OpenSource/ouds-ios) Swift package) for a deeper, production-grade reference implementation of these same component families.

No Figma file, codebase, or slide deck was attached beyond the above.

## Index

- `styles.css` — root stylesheet, imports every token file below.
- `tokens/` — `colors.css`, `typography.css`, `spacing.css`, `radii.css`, `fonts.css`, `base.css`.
- `components/` — 18 reusable primitives, grouped by concern:
  - `actions/` — Button
  - `controls/` — Checkbox, Radio, Switch, Chip, TextInput, TextArea, PasswordInput, PinCodeInput
  - `indicators/` — Badge, Tag
  - `layout/` — Divider, Card
  - `dialogs/` — Alert
  - `navigation/` — Link, TabBar, ToolBar
  - `content/` — ListItem
- `guidelines/` — foundation specimen cards (Colors, Type, Spacing, Brand groups in the Design System tab).
- `ui_kits/store-app/` — click-through iOS Store app recreation (Home feed, Product buy page, Account) built from the components above.
- `assets/` — see Iconography below; **no logo asset is included** (see Assets & Logo note).
- `SKILL.md` — Claude Code / Agent Skill packaging of this system.

## Content Fundamentals

- **Voice:** confident, minimal, declarative. Short sentence fragments as headlines ("Titanium. So strong. So light. So Pro."), not full marketing paragraphs.
- **Person:** headlines describe the product in third person; supporting body copy and CTAs address the reader directly ("Learn more", "Buy", "Add to Bag").
- **Casing:** sentence case throughout — headlines, buttons, nav labels. No ALL CAPS except tiny eyebrow/section labels used sparingly.
- **Punctuation:** periods used for rhythm inside headlines even when not grammatically required — each short clause reads as its own beat.
- **Emoji:** never used in product copy or UI labels.
- **Vibe:** quiet confidence. The product does the talking; copy gets out of the way. No exclamation points, no hype language, no urgency/scarcity messaging.
- **CTAs:** always exactly two words or fewer ("Learn more", "Buy", "Shop now") — never a full sentence.

## Visual Foundations

- **Color:** one interactive color system-wide — Action Blue `#0066cc` (Sky Link Blue `#2997ff` on dark tiles only). No second accent color anywhere. Neutrals are nearly-black ink (`#1d1d1f`), pure white, and a signature off-white "parchment" (`#f5f5f7`) — never pure gray.
- **Type:** SF Pro Display for headlines (weight 600, tight negative letter-spacing), SF Pro Text for everything ≤19px. Body copy runs at 17px (not the SaaS-standard 16px) with a relaxed 1.47 line-height. Weight ladder is 300/400/600/700 — 500 is deliberately never used.
- **Spacing:** 8px base unit; product tiles carry 80px vertical padding; cards 24px; buttons 8–14px × 15–28px.
- **Backgrounds:** full-bleed, edge-to-edge product photography. No gradients anywhere in the system — atmosphere comes from the photography itself, never a CSS gradient overlay. No decorative patterns or textures.
- **Animation:** minimal. The only documented motion is `transform: scale(0.95)` on button press. No hover-darken states are documented (default + active/pressed only); no bounce, no parallax.
- **Hover states:** not part of the documented system — Apple's source material only defines default and active/pressed.
- **Press states:** `scale(0.95)` transform on every button, universally.
- **Borders:** hairline only (`1px solid #e0e0e0` / `rgba(0,0,0,0.08)`), used on utility cards, configurator chips, and the search input. Never a colored or thick border.
- **Shadows:** exactly **one** drop-shadow in the entire system — `3px 5px 30px rgba(0,0,0,0.22)` — reserved for product photography resting on a surface. Never applied to cards, buttons, or text.
- **Blur / transparency:** `backdrop-filter: saturate(180%) blur(20px)` on the frosted sub-nav and the floating sticky "Add to Bag" bar — the only two frosted-glass surfaces in the system.
- **Layout:** full-bleed section tiles with zero gap between them — the color change (light ↔ dark ↔ parchment) *is* the divider, never a border.
- **Corner radii:** binary grammar — `0` for full-bleed tiles, `8px` for compact utility rects, `18px` for utility/grid cards, and a full `pill` for every CTA/chip/search input. `11px` (Pearl Button) is the one rare in-between value; nothing else.
- **Cards:** two shapes only. Full-bleed **product tiles** (no radius, no border, no shadow, color-block background) and bordered **utility cards** (`18px` radius, 1px hairline, no shadow — elevation comes from the color change, not from card chrome).
- **Imagery tone:** photographic, high-key studio lighting, neutral-to-cool color grading, no visible grain or filters. Products are the entire subject — no lifestyle clutter in frame.

## Iconography

- **No SVG icon set or icon font was provided in either source.** The uploaded analysis documents interaction affordances (search glyph, close ×, chevron, circular controls) structurally, not as concrete asset files.
- **This system uses text/unicode glyphs as placeholders** (⌕ search, × close, › chevron, simple emoji in the Store-app tab bar) — flagged here as a substitution. **Ask:** please attach Apple's real SF Symbols set (or an exported icon sprite/SVGs) and these will be swapped in directly.
- Apple's own products use **SF Symbols** (a proprietary, weight-matched glyph system tied to SF Pro) — if building production Apple-adjacent work, SF Symbols is the correct system to reference instead of a generic icon font.
- Do not substitute a generic CDN icon set (Lucide/Heroicons) as a long-term stand-in without flagging it — icon weight/style must match SF Symbols' optical grade, which off-the-shelf sets do not replicate well.

## Assets & Logo

**No Apple logo, wordmark, or brand mark was provided by any attached source, and none has been created.** Per policy, Apple's real logo is never drawn, reconstructed, or approximated from memory. Everywhere a mark would normally appear (nav bar, splash), the brand name is rendered in plain SF Pro Display type instead — see the "No Logo Available" card in the Brand group. No product photography, illustrations, or background imagery were provided either; UI kit screens use solid-color placeholder blocks in place of real product renders. **Ask:** attach real product photography and an Apple wordmark/logo asset (if you have rights to use them) to replace these placeholders.

## Intentional Additions

- **Card** — not a named family in the OUDS component inventory, but explicitly specified in `DESIGN-apple.md` as `product-tile-*` and `store-utility-card`; added because Apple's own source defines it even though the secondary repo doesn't.
- **ListItem** — generalizes the OUDS "BulletList" family into a reusable content row (spec sheets, Settings rows, dense footer links), since BulletList itself is a toolbox-app-specific construct rather than a portable primitive.
- Toolbox-internal utilities from the OUDS repo that aren't real UI primitives (e.g. `ColoredSurface`, a demo-app color-picker screen) were intentionally **not** ported — they document the Orange demo app's own architecture, not a component Apple's product design would ship.

## Components

Actions/Button · Controls/Checkbox · Controls/Radio · Controls/Switch · Controls/Chip · Controls/TextInput · Controls/TextArea · Controls/PasswordInput · Controls/PinCodeInput · Indicators/Badge · Indicators/Tag · Layout/Divider · Layout/Card · Dialogs/Alert · Navigation/Link · Navigation/TabBar · Navigation/ToolBar · Content/ListItem

## Known Gaps

- Font files: SF Pro is proprietary and unavailable; Inter (Google Fonts) is loaded as the visual fallback everywhere off Apple hardware, where `system-ui`/`-apple-system` already resolves to real SF Pro. See `tokens/fonts.css`.
- Form validation/error states beyond a basic red-tinted `error` prop were not documented in the source material.
- Dark-mode counterparts for utility cards/store surfaces were not documented in the source.
