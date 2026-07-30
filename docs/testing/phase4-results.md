# Phase 4 Ledger (SOLO) — Results (recorded 2026-07-30)

Verdict: **CLEARED** — 20 pass · 0 fail · 0 skip on v0.8.1. All seven blockers green.

Round 1 (v0.8.0) failed T1: Tax Administration silently filtered out any store it couldn't
assess, so "No store owes the county anything" hid *which* condition was unmet. v0.8.1 lists
every chartered store and greys the unassessable ones with the reason (NO OWNER / NO LEVY /
REPOSSESSED), and `set_price` now starts the tax cycle just as `set_tax_rate` did.

## What this run proves

- **Tax collects itself** — reserve first, operating for the shortfall, receipt letter, and the
  due date re-anchored on the day it was paid (T2).
- **Delinquency and seizure work end to end** — failed collection → delinquent chip + notice,
  grace expiry → repossession with ledgers swept to the treasury, and the event trail reads
  `tax_delinquent` → `tax_seizure` → `repossessed` in order (T3, R1, R2).
- **The absence clock works** — warn once per absence, exemptions honoured, revoke at 45 days (A1-A4).
- **Buy orders hold their own money** — paid from operating, goods to the back room, auto-pause
  when unfunded, auto-fill at target (B1-B4).
- **The treasury reconciles** — the fund's running balance never disagrees with the tile (L3).

## Project status

| Gate | Result |
|---|---|
| Phase 0 — skeleton & tech prep | CLEARED 9/9 |
| Phase 1 — NPC stores & storefront | CLEARED 17/17 |
| Phase 2 Ledger I — Commerce Bureau | CLEARED 16/16 |
| Phase 2 Ledger II — management (solo) | CLEARED 10/10 |
| Phase 3 — staff systems (solo) | CLEARED 10/10 |
| Phase 4 — economy engine (solo) | **CLEARED 20/20** |
| Duo Ledger — every two-hand item, Phases 2-4 | CLEARED 20/20 |

**Every gate in the plan is green. Phase 5 (release candidate) is all that remains:**
analytics (H5/H7), the full locale pass (A3), config-validation hardening (A4), docs 00/01
finalised, the integration surface documented in the README, and a `v1.0.0-rc` tag.
