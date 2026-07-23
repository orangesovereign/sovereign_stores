# sovereign_stores

Unified commerce for Sovereign County RP (RedM / VORP Core): government-run **NPC stores** and
player-owned **storefronts** with employees, dual ledgers, property taxes, buy orders, weapon
provenance serials, and a commerce admin dashboard. Replaces `vorp_stores` entirely.

**Status: Phase 0 — skeleton.** Boots, validates config, verifies schema, `/stores_diag`. No
gameplay yet. See [docs/03-CODING-PLAN.md](docs/03-CODING-PLAN.md) for the phase roadmap.

## Requirements

- [vorp_core](https://github.com/VORPCORE/vorp_core) · vorp_inventory **1.7.3 Cas fork** (this
  server's build — see [docs/05-PROBE-RESULTS.md](docs/05-PROBE-RESULTS.md) for the verified API
  contract) · oxmysql
- sovereign_notify · sovereign_menus
- sovereign_postoffice (optional — government letters queue until its `SendMail` ships)

## Install

1. Run `sql/install.sql` against the server database (idempotent — safe to re-run).
2. `ensure sovereign_stores` after vorp_core, vorp_inventory, sovereign_notify, sovereign_menus.
3. Check the boot banner, then run `stores_diag` in the server console (or `/stores_diag` in game
   as an admin) — everything should be green.

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/01-BASELINE.md](docs/01-BASELINE.md) | vorp_stores parity floor, verified dependency APIs, risk register |
| [docs/02-FEATURES.md](docs/02-FEATURES.md) | Frozen v1 feature list (all tech-prep verified) |
| [docs/03-CODING-PLAN.md](docs/03-CODING-PLAN.md) | Phase roadmap with testing-ledger gates |
| [docs/05-PROBE-RESULTS.md](docs/05-PROBE-RESULTS.md) | Authoritative Cas-inventory bridge contract (TP-1) |
| [sovereign-shops-design-v1.md](sovereign-shops-design-v1.md) | Original design document |

Architecture follows the sovereign house conventions: every external call goes through
`shared/bridge.lua`; server-authoritative everything; typed ledger writes; idempotent SQL with a
dated upgrade log; per-phase testing ledgers.
