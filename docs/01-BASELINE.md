# sovereign_stores — 01 BASELINE (Tech Prep Research)

Research date: 2026-07-23. Everything below was verified by reading actual source on the F: drive
(no guesswork). Where source is unreadable (escrow), the item is marked **PROBE** and goes to the
TP-1 runtime probe list at the bottom.

---

## 1. What vorp_stores does today (parity floor)

Source: `F:\Sovereign County RP\_reference\vorp_stores` (official VORPCORE Lua version, cloned 2026-07-23).
sovereign_stores replaces it entirely; v1 must match or consciously supersede every behavior here.

| # | vorp_stores behavior | Notes from source |
|---|---|---|
| P1 | Config-defined unique stores (per-store: prompt, open distance, NPC ped model + heading, blip) | `config.lua` per-store tables |
| P2 | Buy list + sell list per store, item categories with label/desc/image | `shared/buyitemsCFG.lua` / `sellitemsCFG.lua` |
| P3 | Job lock + job-grade lock per store (`AllowedJobs`, `JobGrade`) | empty list = public |
| P4 | Store hours on the **in-game clock** (`GetClockHours`); closed = prompt disabled, blip recolored (`BLIP_MODIFIER_MP_COLOR_2`) | `client.lua:184-200,230-251` |
| P5 | Roaming stores: `useRandomLocation` picks from a pool at resource start (server-side, synced) | `server.lua:378-383` |
| P6 | Random prices at restart (`randomprice` per item overrides base price) | `server.lua:355-376` |
| P7 | Dynamic stock limits (`itemLimit`): buys decrement, player sales replenish; **session-only, resets on restart** | `server.lua:45-71` |
| P8 | Currency per item: cash (`addCurrency(0,…)`) or gold (`addCurrency(1,…)`) | `server.lua:130-141` |
| P9 | Weapons sold/bought as catalog entries (`weapon=true`): `createWeapon`, sell via `getUserInventoryWeapons`+`subWeapon`+`deleteWeapon` | `server.lua:81-102,157-187` |
| P10 | Decay-aware selling: block decayed items, min-percentage gate, optional price scaling by condition % | `Config.AllowSellItemsWithDecay`, `DecayPercentage`, `SellItemBasedOnPercentage` |
| P11 | canCarry checks before purchase (`canCarryItem`, `canCarryWeapons`) | `server.lua:236,246` |
| P12 | **Single-shopper lock** — one player per store at a time (`storesInUse`) | `server.lua:336-353`; released on drop |
| P13 | Discord webhook log of every buy/sell via `Core.AddWebhook` | `server.lua:38-43` |
| P14 | Translations file, DevMode `/reload`, HUD-hide hook on menu open | `config.lua` |
| P15 | UI = vorp_menu list menus (no NUI of its own) | `client.lua` MenuData |

Known weaknesses we intend to beat: session-only stock (P7), one-shopper-at-a-time (P12),
no persistence, no ownership, no ledgers, config-only catalogs, list-menu UX (P15).

---

## 2. Verified dependency APIs

### 2.1 vorp_core (`_reference/vorp_core`, v3.3) — VERIFIED from source

- Acquire: `exports.vorp_core:GetCore()` (server + client).
- `Core.getUser(src)` → user; **fields not functions**: `user.getUsedCharacter`, `user.getGroup`, `user.source`.
- Character fields: `charIdentifier`, `identifier`, `money`, `gold`, `group`, `job`, `jobGrade`, `firstname`, `lastname`, …
- Money: `Character.addCurrency(code, qty)` / `removeCurrency(code, qty)` — **0=cash, 1=gold, 2=rol**. Auto-updates statebag + HUD.
- Admin gate: `user.getGroup == "admin"` (account-level group) and/or `IsPlayerAceAllowed(src, ace)`. No isAdmin export.
- Callbacks: `Core.Callback.Register(name, function(source, cb, ...))` server; client `Core.Callback.TriggerAwait(name, ...)` (returns value) or `TriggerAsync`.
- Webhooks: `Core.AddWebhook(title, url, description[, color, name, logo, footerlogo, avatar])` — server only.
- Client character data: `LocalPlayer.state.Character` statebag (**PascalCase**: `Money`, `Gold`, `Group`, `Grade`, `Job`, `CharId`), gate on `LocalPlayer.state.IsInSession`. Event `vorp:SelectedCharacter` (server-side form carries `(source, characterTable)`).
- vorp_utils is **deprecated** (README says use vorp_lib) — do not depend on it.
- **vorp_banking has zero exports** — no API to credit/debit bank accounts. Bank integration would mean direct SQL on `bank_users` (columns: name, identifier, charidentifier, money, gold, invspace). Decision: out of scope for v1 unless owner says otherwise.

### 2.2 Cas-inventory (deployed: `F:\Sovereign County RP\resources\vorp_inventory`, v1.7.3) — PARTIALLY ESCROWED

Fork of current-gen vorp_inventory, author "Original: VORP & EDITED BY CODE AFTER S*X".
`.fxap` escrow: **all `server/` and most `client/` files are encrypted.** Readable: `config/*`,
`languages/*`, `shared/models/ItemClass.lua`, `shared/handler/*`, `shared/services/UtilityService.lua`,
`client/exports.lua`, `fxmanifest.lua`.

VERIFIED facts (from readable files):
- API style is modern per-function exports (export-return); deprecated `exports.vorp_inventory:vorp_inventoryApi()` table also declared (`fxmanifest.lua:70`).
- Server ops that certainly exist (webhook color config enumerates them): addItem, subItem, useItem, addWeapon/registerWeapon, subWeapon, custom-inventory TakeFrom/MoveTo.
- Metadata: free-form table per item stack; matching is **deep table-equality** (`SharedUtils.Table_equals`); different metadata = separate stack.
- Decay: `maxDegradation` (minutes, from `items` DB row) → `percentage` computed from timestamps; `isDegradable = maxDegradation > 0`; `useExpired` gates expired use. (`ItemClass.lua:96-134`)
- Stack limit: `limit == -1` unlimited, else per-item limit (`ItemClass.lua:231`).
- Slot-based main inventory (`SlotColumns=5`, `DefaultMaxSlots=30`), 5-slot CTRL+1..5 hotbar (cas_ addition).
- Custom-inventory layer exists with bags (`config/bags.lua`: label, maxWeight, maxSlots, acceptWeapons, allowedItems, propModel) and stashes (`config/stash.lua`: + scope private/job/public, job, jobGrade). Global `ForceWeightMode`/`DefaultWeightLimit` (config.lua:331-336) proves `useWeight` capacity mode.
- Item type taxonomy `config/groups.lua`: types 0-11 (2=medical, 3=foods, 4=tools, 5=weapons, 6=ammo, 7=documents, 9=valuables, 11=herbs).
- Client exports (`client/exports.lua`): `closeInventory()`, `getInventoryItem(s)`, weapon default label/desc/weight/name lookups, ammo helpers.
- Item images: `html/img/items/**` is declared "the canonical item image directory (shared with other scripts)" (`fxmanifest.lua:65-66`) → storefront NUI can use `nui://vorp_inventory/html/img/items/<item>.png`.
- Inactive leftovers in the folder: `README.md`, `config/config_server.lua`, most of `html/` are stock-v2 files **not loaded by the manifest** — do not treat them as truth.

**PROBE (TP-1)** — cannot be read from source; must be confirmed on the dev server with a throwaway
probe resource (pattern: `sovereign_medical/spikes/sovereign_casprobe`):
1. Exact signatures/arg order (esp. callback position) for: addItem, subItem, subItemById, getItem, getItemCount, getUserInventoryItems, canCarryItem, getUserInventoryWeapons, createWeapon (custom serial/label params!), subWeapon, deleteWeapon, canCarryWeapons, setWeaponSerialNumber, setWeaponCustomLabel.
2. Whether exports return values synchronously (no cb) like stock v2, or require callbacks.
3. Custom inventory API set + `registerInventory(data)` accepted fields (id, name/label, limit/maxSlots, shared, useWeight, acceptWeapons, whitelists, charid permissions).
4. DB table names after `cas_sqlMigrate` (`SHOW TABLES` + describe items/character_inventories/items_crafted/loadout).
5. Whether gold currency is actually usable on this server.

### 2.3 sovereign_notify (v1.2.1) — VERIFIED

Server: `exports.sovereign_notify:Notify(src, payload)` · `Objective(src, text)` · `Tick(src, text)` ·
`Card(src, variant, title, body)` · `Subtitle(src, speaker, text, ms)`. Client: same minus `src`.
Card variants: `started | complete | failed | cancelled | nil`. Never takes NUI focus.
House practice: wrap in pcall; optional fallback if resource not started.

### 2.4 sovereign_menus (v1.0.0) — VERIFIED

Client-only list menu: `exports.sovereign_menus:Open(def, onSelect, onClose)` → bool, `Close()`, `IsOpen()`.
`def = { title, subtitle?, footer?, items = { {id,label,description?,rightText?,disabled?}, … } }`.
Takes NUI focus; re-Open inside onSelect = submenu pattern. Good for register/quick interactions;
NOT sufficient for the storefront/dashboard NUI (which the design doc scopes as its own UI anyway).

### 2.5 sovereign_postoffice (v1.0.0 scaffold) — VERIFIED, PARTIAL

Working exports: `GetBoxForCharacter(charid)` → boxNumber, homeOffice · `BoxExists(box)` ·
`GetUnreadCount(box)` · `isBooted()`.
**`SendMail(opts)` is a STUB** → returns `false, 'not_implemented'` (its Phase 3). Contract is already
designed: `{ toBox, fromName (REQUIRED), fromBox=nil for official no-reply, subject, body, stationery?,
cash?, notice? }`; schema supports it (`from_box` nullable, `from_name NOT NULL`, `is_notice` flag).
→ Tax letters (design §5) depend on postoffice Phase 3 **or** shipping with a graceful fallback
(queue + notify) until SendMail lands. Mail bridge must check `isBooted` + tolerate `not_implemented`.

### 2.6 House architecture conventions (from sovereign_stables / sovereign_medical / sovereign_postoffice)

- `shared/bridge.lua` is THE choke point for every external call (not a `bridge/` folder — supersedes design-doc §14 sketch). Lazy pcall-cached `Bridge.core()`, `IS_SERVER` guards, `Bridge.required` list, `Bridge.checkDependencies()`.
- Layout: `config/` (config.lua + per-domain + locales/en.lua) · `shared/` (events.lua, util.lua, validate.lua, bridge.lua, …) · `client/` (feature-per-file, core.lua last) · `server/` (db.lua first, core.lua boot) · `sql/` (idempotent install.sql + dated append-only upgrades.sql) · `docs/` (00-README, 01-BASELINE, 02-FEATURES, 03-CODING-PLAN, 04-UI-DESIGN, testing/) · `ui/`.
- Boot: `server/core.lua` thread → validate config, check deps, verify schema (`SHOW TABLES LIKE`), print banner, register `/<resource>_diag`, export `isBooted`.
- DB via oxmysql promise wrappers (`Db.awaitQuery/awaitExecute/awaitInsert`); resource owns `sovereign_*` tables; no auto-migrations — verify loudly.
- NUI tiers: full app = React 19 + Vite, ship `ui/dist` only; simple = plain HTML/CSS/JS shell. Fonts/tokens: `sovereign-brand.css` (Rye / Special Elite / Crimson Text, `--sov-*`) for MDT-class UIs; `sc-theme.css` (Cinzel / Libre Baskerville / IM Fell English, `--sc-*`) for parchment-class UIs.
- fxmanifest: cerulean, rdr3_warning, lua54, author 'Sovereign County RP', repository URL, explicit commented load order, `dependencies {}` block (oxmysql checked at runtime instead).

---

## 3. Constraints & risks register

| ID | Finding | Impact | Mitigation |
|----|---------|--------|-----------|
| R1 | Cas-inventory server code escrowed | Cannot read export signatures | TP-1 probe resource on dev server before Phase 1 transaction code |
| R2 | postoffice `SendMail` stubbed | Tax letters (§5) blocked | Mail bridge with fallback queue + coordinate postoffice Phase 3 |
| R3 | vorp_banking has no exports | No clean "pay to bank" | v1 = cash (+ gold?) only; revisit when a banking API exists |
| R4 | vorp_utils deprecated | Don't use its prompt/ped helpers | Native prompts/peds like vorp_stores + house patterns |
| R5 | Live Discord webhook URLs w/ tokens sit in cleartext in deployed `vorp_inventory/config/logs.lua` | Token leak risk if folder is ever shared/pushed | Owner should rotate + keep out of any repo |
| R6 | Design doc §14 architecture sketch predates house conventions | Drift | This baseline supersedes: `shared/bridge.lua` + house layout |
| R7 | vorp_stores stock limits are session-only | Not a real economy | Ours persist in DB (design §13) |

---

## 4. Reference paths

- Design doc: `sovereign-shops-design-v1.md` (project root)
- Testing ledger template (only authorized design): `resource/testing-ledger-template.html`
- vorp_stores source: `_reference/vorp_stores` · vorp_core: `_reference/vorp_core`
- Deployed Cas-inventory: `F:\Sovereign County RP\resources\vorp_inventory` (F: drive copies are authoritative)
- Probe pattern to copy: `sovereign_medical/spikes/sovereign_casprobe`
