# Duo Ledger — Results (recorded 2026-07-27)

Verdict: **CLEARED — 20 pass · 0 fail · 0 skip.** All five duo blockers green.

Every two-hand item accumulated across Phases 2-4 confirmed in one session. This retires
every ASSUMED FUNCTIONAL annotation the standing duo process had left open.

## What this settles

| Item | Was |
|---|---|
| **D3** | The "clerk squints" multi-quantity purchase (duo round 1 blocker). Now passes. The named-refusal instrumentation added in v0.7.1 (`unknown_item` / `bad_qty` + a console WARN naming the cart line and live catalog) stays in place as a permanent diagnostic. |
| **D4** | Shelf overdraw — fixed at the source in v0.7.1: the basket clamps to live stock, and a genuine race is refused by name. |
| **D10** | Promotion double-role — fixed in v0.7.1: `setCoOwner` consumes the employee row, so one person holds one role. |
| **D14-D17** | Phase 3 wages proved with a REAL employee: hourly payout, the daily minimum, the ledger-short unpaid case, and the shared notes board. |
| **D18-D20** | Phase 4 buy orders proved with a REAL seller: paid from operating, goods to the back room, unfunded orders refuse, and weapons never appear as buy orders. |

## Still open

The **Phase 4 SOLO ledger** (artifact `d813142b`) is the outstanding gate — phase gates count
solo blockers, and Phase 4's schedulers (tax collection, delinquency, repossession, the absence
clock, county letters) have not yet been run. Phase 5 begins when it clears.
