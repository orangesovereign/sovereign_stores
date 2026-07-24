# Phase 2 Ledger I (Commerce Bureau) — Results (recorded 2026-07-24)

Verdict: **CLEARED** — 16 pass · 0 fail · 0 skip on v0.4.0. All six blockers green.

The county's first stores were chartered through the Bureau: code uniqueness enforced (C2),
ledger adjustments with overdraft refusal (D2/D3), repossession swept exactly $25 to the
government fund (D4), the full event trail recorded (D5), and a clean no-red sweep (X1).

One UX finding from C2's note: when a charter is refused, the feedback toast rendered behind
the Assign Store modal, so the reason was invisible and the modal appeared stuck.
**Fixed in v0.5.1** — errors now display inside the modal itself.

Remaining Phase 2 gate: **Ledger II** (Management workspace + player-store trading, built in
v0.5.0) — docs/testing/phase2b-ledger.html.
