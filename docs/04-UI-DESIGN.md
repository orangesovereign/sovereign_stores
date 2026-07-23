# sovereign_stores — 04 UI DESIGN (owner-approved concept, 2026-07-23)

The owner supplied three concept screens ("Commerce NUI Concept") that define the visual system
for every panel in this resource. **This document is the binding spec.** The concept's top bar
(Storefront / Management / Staff / Admin switcher) is an explorer shell only — the real product
opens each panel in its own context (register prompt, back-room prompt, admin command).

**Rule zero — readability.** The owner's one correction: the concept's tiny print is unreadable.
Keep the look, scale the type up. Base body ≥ 15px in the NUI; labels ≥ 11px with letterspacing;
nothing below 11px, ever. Numbers use tabular figures.

## Design language

- **Ground:** near-black panels (#0a0a0a family) on a dimmed scrim; raised cards a warm dark
  umber-brown; 1px brass hairline borders; generous dark padding. A thin outer frame around the
  whole panel.
- **Accents:** brass/gold for structure, labels, monograms, chart bars (brass→oxblood gradient);
  oxblood red strictly for primary actions (Complete Purchase, Assign Store, active nav pill) and
  danger states (TAX DELINQUENT, REPOSSESSED chips).
- **Type:** display = Rye (store names, section titles); labels/eyebrows = Cinzel, uppercase,
  letterspaced (engraved-plate serif — the concept's typewriter face was REJECTED by the owner
  2026-07-23, do not reintroduce it); body = Crimson Text. All bundled locally as woff2 (OFL).
  No CDN, ever.
- **Monogram:** rotated-square (diamond) badge with the store's initial (or code letter),
  brass border on black; used top-left of every panel identity block.
- **Status chips:** small bordered uppercase chips — OPEN (green/sage), CLOSED (neutral),
  TAX DELINQUENT (oxblood), INACTIVE WARNING (amber), REPOSSESSED (oxblood filled).
- **Stat tiles:** icon in a bordered square, uppercase eyebrow label, huge number, small
  context line under (e.g. "+$886.40 today", "$213.50 due Aug 01").

## Screen 1 — Storefront (buyer; Phase 1, restyle NOW)

- **Header band:** diamond monogram · eyebrow "EST. {year} · {place}" (Cinzel, brass) ·
  store name huge in Rye · tagline in italic body under it · right side: STORE STATUS
  ("Open for Business" with green dot) + ✕ close.
- **Tab bar:** "Shop Goods" / "Sell to Store" with a pill badge showing the count of things the
  clerk buys (later: active buy orders).
- **Left rail — DEPARTMENTS:** icon + label rows from the store's categories, active row
  highlighted with brass; "All Goods" first with chevron. Below: **"Today's notice"** card —
  short owner/operator-authored text (config `notice`), hand-italic on a raised card.
- **Goods grid (center):** cards with item art on a dark well, top-left sale badge ("20% OFF",
  oxblood), top... in-card: stock line ("18 in stock" / "Only 4 left" amber when low — player
  stores; NPC stores are infinite so the line is omitted), category eyebrow, item name, one-line
  description, price row (sale: struck original + red sale price), basket button bottom-right.
- **Right rail — YOUR ORDER:** basket icon, "n selections", line items with art thumb + name +
  unit price + − qty + steppers; then Subtotal / County fee / **Total due** (big, brass), oxblood
  **Complete Purchase** button, and the note "Payment will be taken from the cash carried on
  your person."
- **Footer:** "{Store name} · Store Code {XYZ}" left · "ESC Close" right.

## Screen 2 — Store Management (owner/co-owner; Phase 2)

- **Left rail:** monogram + "{TOWN} · {CODE} / Store Management"; user card (initials disc,
  name, role); WORKSPACE nav: Overview · Stock & Storage ("3 low" badge) · Buy Orders (count) ·
  Employees ("4/6") · Ledgers · Storefront · Notifications; footer: Preferences, Close panel.
- **Header:** eyebrow "OWNER & CO-OWNER CONTROLS", title = section name; right: bell with unread
  dot + **Store Open** toggle button (power icon).
- **Overview:** four stat tiles — Operating Ledger ($ + "+$X today") · Tax Reserve ($ + "$X due
  {date}") · Today's Sales ($ + "n customer orders") · Staff on Shift (n + "of m employees").
- **Sales Activity** (past seven days): vertical bar chart, brass→oxblood gradient bars, day
  initials under; beneath: Gross sales / Buy-order payouts (negative) / Net movement; "View
  ledger" ghost button.
- **Store Notices** (needs attention): icon rows — tax reserve short, low stock (item names),
  sale ending (time left) — each with chevron.
- **Recent Transactions:** typed rows — disc initial (S/P/W/D), type + detail line, signed amount
  (+ green / − red), relative time.
- **Staff on Shift (live presence):** initial disc, name, "Verified at storefront", time on
  shift, accrued pay; footnote line "NPC cashier is away while staff are present."

## Screen 3 — Commerce Bureau (admin; Phase 2)

- **Left rail:** SC diamond + "TERRITORIAL OFFICE / Commerce Bureau"; Administrator card ("Chief
  Commerce Officer"); nav: Store Directory (count) · Store Detail · Tax Administration ("2 due") ·
  Commerce Analytics · Inactivity Monitor (count) · Government Fund · Event Log.
- **Header:** eyebrow "SERVER ADMINISTRATION", title "Store Directory"; right: bell + oxblood
  **+ Assign Store** button.
- **Stat tiles:** Player Stores (n + "m currently open") · Government Fund ($ + "+$X this month") ·
  Delinquent (n + "one deadline tomorrow", red-edged tile) · Inactivity Flags (n + "one reaches
  45d soon").
- **Directory table:** CODE chip (3 letters, bordered) · Store (name + "Player Store" subline) ·
  Category · Owner ("—" when repossessed) · Status chip · Last Login (relative) · chevron to
  detail. Search field ("Search stores or owners…") + "All statuses" filter.
- **Footer:** "Sovereign County Commerce Bureau · Live server overview" · "All figures shown in
  dollars."

## Implementation notes

- Shared component kit (Phase 2 extracts from storefront): `Monogram`, `StatTile`, `StatusChip`,
  `RailNav`, `TypedRow`, `Bars` — one `sovereign-ui.css` on the token set.
- Icons: minimal geometric inline SVGs (16px, 1.5px stroke, brass) — box, plate/provisions,
  wrench/supplies, arrow/hunting, horse, coin/sundries, ledger, bell, power, shield, clock,
  bank. No icon fonts, no emoji.
- County fee line exists in the order panel from day one (shows $0.00 until a levy feature ever
  lands) — the mockup shows it and it future-proofs the layout.
- All figures in dollars (cash-only ruling); tabular numerals everywhere money or time aligns.
