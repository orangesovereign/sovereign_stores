# sovereign_stores

Unified commerce for Sovereign County RP (RedM / VORP Core): government-run **NPC stores** and
player-owned **storefronts** — employees and wages, a back room and priced shelves, dual ledgers,
property taxes that collect and repossess on their own, buy orders, weapon-provenance serials, a
Commerce Bureau admin dashboard, and commerce analytics. Replaces `vorp_stores` entirely.

**Status: v1.0.0-rc.** Every build phase and the cross-player duo ledger have passed. See
[docs/03-CODING-PLAN.md](docs/03-CODING-PLAN.md) and [docs/testing/](docs/testing/).

## Requirements

- [vorp_core](https://github.com/VORPCORE/vorp_core) · vorp_inventory **1.7.3 Cas fork** (this
  server's build — see [docs/05-PROBE-RESULTS.md](docs/05-PROBE-RESULTS.md) for the verified API
  contract) · oxmysql
- sovereign_notify · sovereign_menus
- sovereign_postoffice (optional — government letters queue until its `SendMail` ships, then flush
  automatically)

## Install

1. Run `sql/install.sql` against the server database (idempotent — safe to re-run). Existing
   installs run any new dated blocks in `sql/upgrades.sql`.
2. `ensure sovereign_stores` after vorp_core, vorp_inventory, sovereign_notify, sovereign_menus.
3. Check the boot banner, then run `stores_diag` in the server console (or `/stores_diag` in game
   as an admin) — everything should be green. A missing table, a config error, or a module that
   failed to load is named in red.

## Configure

- **NPC stores** — one file per type in `config/stores/*.lua`. Each is ONE catalog shared by MANY
  counters: add a location to sell the same goods somewhere new. `config/npc_stores.lua` holds the
  shared settings (town exclusion zones, interact distances) and the full field reference.
- **Everything else** — `config/config.lua`: admin access, employee caps, the tax/inactivity/wage
  schedulers, curated cashier peds, the weapon catalog, and the per-category blip catalog.
- NPC stores are config-only and never appear in the Bureau. Changes need a resource restart.

## Commands

| Command | Who | Does |
|---------|-----|------|
| `/storeadmin` | admin | opens the Commerce Bureau |
| `/mystore` | store staff | opens the management workspace (or press the Manage prompt at your counter) |
| `/stores_diag` | admin / console | prints the boot health report |

Buyers press the Browse prompt at any store counter.

## Integration surface

Other resources build on `sovereign_stores` through **server exports** and **events**. This is the
v1 contract — additions are safe, removals are breaking.

### Exports (server)

```lua
-- Look-ups
exports.sovereign_stores:GetStoreByCode('BWM')          --> store summary | nil
exports.sovereign_stores:GetStoreInfo(storeId)          --> store summary | nil
exports.sovereign_stores:ListStores({ status=, category=, ownedOnly= })  --> array of summaries
exports.sovereign_stores:IsStoreStaff(charid, storeId)  --> 'owner'|'coowner'|'employee' | nil
exports.sovereign_stores:GetStoresForCharacter(charid)  --> array of { id, code, name, role, status }

-- Ownership (for a realty / auction script)
exports.sovereign_stores:AssignOwner(storeId, charid)   --> ok, err   (starts the tax cycle)

-- Weapons (for a law MDT)
exports.sovereign_stores:LookupWeaponSerial('BWM-042187')  --> { serial, weapon, sold_to_charid, store_name, code, created_at } | nil

-- Treasury (for a future government / bank script)
exports.sovereign_stores:GetGovernmentFund()            --> number
exports.sovereign_stores:SpendGovernmentFund(amount, note)  --> ok
```

A **store summary** is `{ id, code, name, category, status, class, ownerCharid, coownerCharid,
taxState, taxDue, coords, balances = { operating, tax } }`.

### Events (server — `AddEventHandler`)

```lua
sovereign_stores:itemPurchased   -- { src, store, total }              a buyer bought from a store
sovereign_stores:itemSold        -- { src, store, item, qty, total }   a player sold into a store
sovereign_stores:storeOpened     -- { store, name, code }
sovereign_stores:storeClosed     -- { store, name, code }
sovereign_stores:employeeClockIn -- { store, charid }
sovereign_stores:repossessed     -- { store, reason, swept }
```

`store` is a numeric id for player stores and a `'p:<id>'` / config key string in buyer-facing
events — check the field shape per event above.

## Architecture

Follows the sovereign house conventions: every external dependency goes through `shared/bridge.lua`;
server-authoritative everything (the NUI never sets a price or a quantity); typed ledger writes are
the money's source of truth and webhooks only mirror them; idempotent `sql/install.sql` with a
dated `sql/upgrades.sql` log; per-phase testing ledgers. Each server module stamps a boot sentinel
so a stale or half-deployed copy names the missing file at boot instead of failing at first use.

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/01-BASELINE.md](docs/01-BASELINE.md) | vorp_stores parity floor, verified dependency APIs, risk register |
| [docs/02-FEATURES.md](docs/02-FEATURES.md) | Frozen v1 feature list (all tech-prep verified) |
| [docs/03-CODING-PLAN.md](docs/03-CODING-PLAN.md) | Phase roadmap with testing-ledger gates |
| [docs/04-UI-DESIGN.md](docs/04-UI-DESIGN.md) | The owner-approved NUI design system |
| [docs/05-PROBE-RESULTS.md](docs/05-PROBE-RESULTS.md) | Authoritative Cas-inventory bridge contract (TP-1) |
| [docs/testing/](docs/testing/) | Per-phase testing ledgers and results |
