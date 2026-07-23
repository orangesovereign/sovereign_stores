# sovereign_stores — 02 FEATURES (v1 Release Candidate — frozen 2026-07-23)

The master feature list, tech-prepped against real source (see [01-BASELINE.md](01-BASELINE.md)).

**Status legend**
- ✅ **Verified** — feasibility confirmed by reading actual source (paths in baseline doc)
- 🔬 **Probe** — feasible per readable code/config, exact call signatures need TP-1 runtime probe (Cas-inventory escrow)
- ⏳ **External** — depends on another script shipping its side (tracked, has a fallback)

**Owner decisions (2026-07-23):** stores are 24/7 (no hours system) · cash only (no gold pricing) ·
NPC stores infinite stock · bank script is in the works — cash-only v1, bank integration point reserved for v2.

---

## A. Core platform

| ID | Feature | Status |
|----|---------|--------|
| A1 | House-convention skeleton: `shared/bridge.lua` choke point, `config/` + locales, `sql/install.sql` + dated `upgrades.sql`, `server/core.lua` boot banner, `/stores_diag`, `isBooted` export | ✅ |
| A2 | Full schema per design §13 (`sovereign_stores*`, `sovereign_weapon_serials`, `sovereign_government_fund`), idempotent install, boot-time verify | ✅ |
| A3 | Locale layer (`config/locales/en.lua`), no hardcoded player-facing strings | ✅ |
| A4 | Config validation at boot with loud, specific errors | ✅ |
| A5 | Future-expansion posture: every external touchpoint behind the bridge; integration events/exports (I3) versioned from day one | ✅ |

## B. NPC stores (government-run)

| ID | Feature | Status |
|----|---------|--------|
| B1 | Config-defined store types (General, Fishing, Pelt Trader, Black Market, Butcher) with per-type buy/sell catalogs; one definition stamped to many map locations (coords/heading/ped/blip each) | ✅ |
| B2 | NPC cashier ped per location (model per store/location, spawn-by-distance like vorp_stores) | ✅ |
| B3 | Blips per location (sprite/label config) | ✅ |
| B4 | **24/7 operation — no hours system** (owner decision; supersedes vorp_stores parity P4) | ✅ |
| B5 | Job/job-grade lock per store — capability kept for parity, config `allowedJobs`, default open | ✅ |
| B6 | Roaming stores (Black Market): server picks location from pool at restart, synced to all, **never a blip**; town exclusion zones (shared config) filter the pool + console-warn bad pool entries | ✅ |
| B7 | **Infinite stock** for NPC stores (owner decision); catalog prices fixed in config | ✅ |
| B8 | Sell-to-store lists with per-item prices; decay-gated (min condition %) and optional condition-scaled payout | ✅ (TP-1: `percentage`/`isDegradable` live on every stack) |
| B9 | All NPC revenue → government fund with typed history | ✅ |

## C. Buyer storefront (one NUI for both store classes)

| ID | Feature | Status |
|----|---------|--------|
| C1 | React 19 + Vite NUI, sovereign noir tokens (Rye/Special Elite, `--sov-*`), ships `ui/dist` only | ✅ |
| C2 | Cart checkout: multi-item, single server transaction, single ledger entry + notify | ✅ (TP-1: addItem/subItem/canCarry sync returns) |
| C3 | Concurrent shoppers — no store lock; stock is server-authoritative, validated at checkout | ✅ |
| C4 | Categories, text search, stock counts ("3 left" / out-of-stock) — player stores; NPC stores show catalog without counts (infinite) | ✅ |
| C5 | Item images from Cas-inventory canonical dir (`nui://vorp_inventory/html/img/items/…`, declared shared in its fxmanifest) | ✅ |
| C6 | Condition display before purchase for decayable items (percentage from item metadata) | ✅ (TP-1) |
| C7 | **Cash only** (owner decision) — prices in dollars, `removeCurrency(0, …)`/`addCurrency(0, …)` | ✅ |
| C8 | canCarry enforcement before charging (items + weapons) | ✅ (TP-1: both return booleans) |
| C9 | Closed player store → closed notice screen w/ owner-set message | ✅ |

## D. Player stores — ownership & catalog

| ID | Feature | Status |
|----|---------|--------|
| D1 | Store entity: unique 3-letter code (admin-set), status `open/closed/repossessed`, register coordinate | ✅ |
| D2 | Roles: owner + 1 co-owner + 5 employees (caps in config); permission flags STOCK / FUNDS_DEPOSIT / FUNDS_WITHDRAW / PRICES / STOREFRONT as bitfield | ✅ |
| D3 | Shelf stock (priced, categorized, metadata-preserving) + back-room storage on the Cas custom-inventory DATA layer (`sovstore_<id>`); storage viewed/managed in OUR store NUI (native `openInventory` UI confirmed non-opening on dev — see 05 §caveat) | ✅ (TP-1: full register/add/get/remove cycle confirmed) |
| D4 | Per-item sales: % off + end time, auto-expiring server-side, struck-through pricing in NUI | ✅ |
| D5 | Buy orders: price + qty wanted, payout from operating ledger, intake to storage, auto-pause when ledger can't cover | ✅ (TP-1: `addItemsToCustomInventory` confirmed) |
| D6 | Branding: display name, curated accent/motif presets, tagline, closed message; blip label updates live | ✅ |
| D7 | Blip hidden or dimmed while closed (config default) | ✅ |
| D8 | Weapon serials `CODE-XXXXXX`, global uniqueness registry (insert-retry on unique constraint), plus provenance line "Sold by {store}" in weapon custom description | ✅ (TP-1: creation-time serial+label+desc all confirmed; fork has NO auto-serials, so store serials are unique on the server) |
| D9 | Metadata-preserving transactions end-to-end (labels, decay, custom fields travel with the item) | ✅ (TP-1: metadata stack add/sub round-trip net-zero confirmed live) |

## E. Money

| ID | Feature | Status |
|----|---------|--------|
| E1 | Operating ledger: typed transactions (sale/purchase/wage/deposit/withdrawal/adjustment) with running `balance_after` | ✅ |
| E2 | Tax ledger: deposit-only, only automated collection withdraws | ✅ |
| E3 | Government fund: single server-wide balance + typed history; `GetGovernmentFund`/`SpendGovernmentFund` exports for future treasury script | ✅ |
| E4 | Cash only; **bank integration point reserved**: all money moves route through `bridge/money` so the in-works bank script can slot in for v2 without touching feature code | ✅ |

## F. Taxes & store lifecycle

| ID | Feature | Status |
|----|---------|--------|
| F1 | Monthly property tax: % of recorded purchase price, per-store rate, DB-stored due dates (restart-safe scheduler) | ✅ |
| F2 | Delinquency flow: failed collection → 72h deadline → retry → auto-repossession (strip roles, sweep ledgers to gov fund, full log) | ✅ |
| F3 | Government letters (delinquency, repossession, receipts, inactivity warnings) via `sovereign_postoffice:SendMail` | ⏳ postoffice Phase 3 — until then: letters queue in DB + owner gets Card notify; queue flushes when `SendMail` goes live (bridge checks `isBooted`/`not_implemented`) |
| F4 | Inactivity repossession: 30-day warning flag, 45-day repossession off `characters.LastLogin` (verified: core updates it on every character load, `loadcharacter.lua:42`); thresholds + co-owner-resets-clock toggle in config; admin extend/exempt | ✅ |
| F5 | Admin manual overrides: force-transfer, manual repossession, tax adjustment (logged as `adjustment`) | ✅ |

## G. Staff systems

| ID | Feature | Status |
|----|---------|--------|
| G1 | Clock in/out at store; server presence heartbeat (radius + grace period, config) auto-clocks-out wanderers | ✅ |
| G2 | Pay models per employee: hourly (per verified tick) or daily (flat, needs min verified minutes); paid from operating ledger; shortfalls logged as unpaid-wage entries — no debt | ✅ |
| G3 | NPC cashier swap-in: ped spawns when nobody clocked in, despawns on clock-in; same storefront either way | ✅ |
| G4 | Staff panel: notes board (timestamped, attributed), restock checklists, at-a-glance (clock status, accrued pay, low stock, active buy orders) | ✅ |
| G5 | Hire/fire/permissions/wage UI (owner/co-owner only) | ✅ |
| G6 | Low-stock alerts: per-item threshold → staff panel flag + optional owner webhook event | ✅ |

## H. Admin dashboard (commerce MDT)

| ID | Feature | Status |
|----|---------|--------|
| H1 | Directory: all player stores, status badges (open/closed/tax_delinquent/inactive_warning/repossessed), owner, last login | ✅ |
| H2 | Detail view: stock, roster + permissions, both ledgers, event log, buy orders | ✅ |
| H3 | Ownership management: assign owner/co-owner, set code (admin-only, immutable to players), purchase price, tax rate, force-transfer, repossess | ✅ |
| H4 | Tax administration: rates, ledger balances, delinquents server-wide, collection history, gov fund balance | ✅ |
| H5 | Analytics: per-store + server-wide (sales volume over time, top items, wage spend, tax collected, buy-order activity) | ✅ |
| H6 | Inactivity monitor with days-remaining + extend/exempt | ✅ |
| H7 | Owner-facing mini analytics in store management (7/30-day sales, top items) | ✅ |
| H8 | Access gate: vorp account group (`admin` + config list) OR ace `sovereignstores.admin` | ✅ |

## I. Logging & integration

| ID | Feature | Status |
|----|---------|--------|
| I1 | Every event written to DB (ledger + event log) — webhooks are a mirror, never the source of truth | ✅ |
| I2 | Two webhook layers: owner-configured store webhook (event-type toggles) + server admin webhook (everything); own embed builder via PerformHttpRequest (richer than `Core.AddWebhook`, no core dependency) | ✅ |
| I3 | Integration surface: events `sovereign_stores:itemSold/:itemPurchased/:storeOpened/:storeClosed/:employeeClockIn/:repossessed`; exports `GetStoreByCode`, `GetStoreInfo`, `IsStoreStaff(charid, storeId)`, `AssignOwner` (future realty script), `GetGovernmentFund`, `SpendGovernmentFund` | ✅ |
| I4 | All notifications via `sovereign_notify` (Tick/Card/Objective per severity), pcall-wrapped | ✅ |
| I5 | `sovereign_menus` for lightweight register interactions; full NUI for storefront/management/dashboard | ✅ |

## J. Ops & testing

| ID | Feature | Status |
|----|---------|--------|
| J1 | `/stores_diag` + boot health report + `isBooted` | ✅ |
| J2 | Testing ledger per build phase generated from the authorized template (`resource/testing-ledger-template.html`) — exactly that design, no other | ✅ |
| J3 | Repo: github.com/orangesovereign/sovereign_stores; F: drive is the only working location | ✅ |

## Deferred to v2+ (tracked, not forgotten)

In-script store purchase flow (realty script's job) · bank payments (bank script in works — E4 reserves the seam) ·
gold pricing · NPC limited stock/restock economy · delivery orders · seasonal catalogs · loyalty pricing ·
store hours (owner ruled 24/7).

## Open tech-prep items

- **TP-1** — ✅ RESOLVED 2026-07-23. Probe ran clean on dev (net-zero). Authoritative bridge contract: [05-PROBE-RESULTS.md](05-PROBE-RESULTS.md). All former 🔬 features are now ✅.
- **TP-2** — postoffice Phase 3 (`SendMail`) timeline — coordinate; F3 fallback ships regardless.
