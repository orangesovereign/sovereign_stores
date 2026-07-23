# sovereign_stores — 03 CODING PLAN (frozen 2026-07-23)

Feature IDs reference [02-FEATURES.md](02-FEATURES.md). Each phase ends with a testing ledger
generated from `resource/testing-ledger-template.html` (the only authorized design) and a
pass/fail gate before the next phase starts.

---

## Phase 0 — Tech Prep & Skeleton *(no gameplay yet)*

1. **TP-1 probe**: build `spikes/sovereign_storeprobe`, owner runs it on the dev server
   (`/storeprobe <item> <weapon>`), results transcribed to `docs/05-PROBE-RESULTS.md`.
   Gates every 🔬 feature; do not write transaction code before this lands.
2. Repo scaffold per house conventions (A1): fxmanifest, `shared/bridge.lua` (core, inventory,
   notify, menus, mail, money seams — E4), `config/config.lua` + `locales/en.lua`, `shared/events.lua`,
   `shared/util.lua`, `shared/validate.lua`.
3. `sql/install.sql` (A2, full schema incl. serials + gov fund) + `server/db.lua` (oxmysql await
   wrappers, schema verify) + `server/core.lua` boot report, `/stores_diag`, `isBooted` (J1).
4. Git init, push skeleton to github.com/orangesovereign/sovereign_stores.

**Deliverable:** resource boots clean on dev, diag green, probe results documented.
**Ledger:** Phase 0 ledger (boot, diag, schema, probe items).

## Phase 1 — NPC Stores & Storefront NUI *(vorp_stores can be removed)*

- Bridge finalized against probe results (inventory add/sub/get/canCarry wrappers).
- NPC store config model + placements, peds, blips (B1-B3, B5), roaming picker + exclusion zones (B6).
- Storefront NUI v1 (C1): categories, search, cart, buy flow; NPC infinite-stock mode (B7, C4).
- Server transaction engine v1: cart checkout, cash only, canCarry, metadata-aware (C2, C3, C7, C8, D9).
- Sell-to-store for NPC catalogs incl. decay gate/scaling (B8, C6).
- Government fund + typed history (B9, E3 minus spend export polish).
- Item images from Cas-inventory dir (C5). Notifications via sovereign_notify (I4).

**Deliverable:** all NPC store types live; `ensure vorp_stores` deleted from server.cfg.
**Ledger:** Phase 1 ledger (per store type: buy, sell, cart, carry limits, decay, roaming, fund).

## Phase 2 — Player Ownership Core

- Store entity + status lifecycle (D1), roles + permission bitfield (D2).
- Admin dashboard v1 (H1-H3, H8): directory, detail, assign owner/code/price/tax rate.
- Stock + storage management (D3 — path chosen by probe), pricing, categories.
- Open/close + closed screen (C9, D7), branding + live blip (D6).
- Operating ledger with typed transactions + deposits/withdrawals (E1).
- Weapon serials + provenance (D8). Event log foundation (I1).

**Deliverable:** first player store assigned, stocked, selling, ledgered.
**Ledger:** Phase 2 ledger (assignment, permissions matrix, stock, purchase w/ serial, ledger integrity).

## Phase 3 — Staff

- Roster, hire/fire, permissions UI (G5), clock + presence heartbeat (G1).
- Hourly/daily wages, unpaid-wage entries (G2). NPC cashier swap-in (G3).
- Staff panel: notes, restock lists, at-a-glance (G4), low-stock alerts (G6).

**Deliverable:** fully staffed store runs a shift with real wages.
**Ledger:** Phase 3 ledger (clock/presence edge cases, both pay models, cashier swap, panel).

## Phase 4 — Economy Automation

- Buy orders + auto-pause (D5). Sales/discount timers (D4).
- Tax ledger (E2), monthly collection scheduler + 72h delinquency + repossession (F1, F2, F5).
- Letter queue + postoffice bridge w/ `not_implemented` fallback (F3). Inactivity monitor (F4, H6).
- Webhook layers (I2) + integration events/exports finalized (I3, E3 spend export).

**Deliverable:** a store can live and die without admin touch: taxed, warned, repossessed.
**Ledger:** Phase 4 ledger (tax happy path, both failure legs, inactivity clock, buy orders, webhooks).

## Phase 5 — Polish & Release Candidate

- Analytics (H5, H7), tax administration view (H4).
- Full locale pass (A3), config validation hardening (A4), docs 00/04 finalized.
- Integration surface documented for other scripts (I3) — README section.
- Full-regression ledger against the ENTIRE feature list → v1.0.0-rc tag on GitHub.

**Deliverable:** v1 Release Candidate.
**Ledger:** V1 Release-Candidate Ledger (complete, from the authorized template).

---

### Standing rules

- Every external call goes through `shared/bridge.lua`; feature code never names another resource.
- Server-authoritative everything; NUI is presentation only; no client-trusted prices/quantities.
- Money mutations and stock mutations happen in one guarded transaction path with typed ledger writes.
- Dated `sql/upgrades.sql` entries from Phase 1 onward; `install.sql` stays fresh-install-complete.
- Phase gate = its testing ledger passes; regressions reopen the phase.
