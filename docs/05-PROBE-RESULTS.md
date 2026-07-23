# sovereign_stores — 05 PROBE RESULTS (TP-1, resolved 2026-07-23)

Live-verified against Cas-inventory (vorp_inventory 1.7.3, escrowed) on the dev server via
`spikes/sovereign_storeprobe` — `/storeprobe alcohol WEAPON_MELEE_KNIFE`, player connected, net-zero
writes confirmed. This file is the **authoritative contract for `shared/bridge.lua` inventory calls**.
Raw console output lives with the Phase 0 testing ledger.

## Headline findings

1. **Return-style works everywhere.** Every export returns its value synchronously when called from a
   coroutine — no callback juggling needed in the bridge. (Callbacks also work where tested.)
2. **`getItemCount` trap confirmed:** the callback is the **2nd** parameter. `getItemCount(src, item)`
   errors inside the escrowed code ("Item [nil] does not exist in DB" + attempts to call the string).
   Always call `getItemCount(src, nil, itemName)`.
3. **This fork does NOT auto-generate weapon serials** — `createWeapon(src, wep)` leaves
   `serial_number` as an empty string (stock v2 auto-fills it). Our `CODE-XXXXXX` stamps will be the
   only serials on the server → provenance is even more distinctive.
4. **Creation-time serial/label/desc all work** with the v2 argument order — one call does everything
   for weapon sales (D8). `setWeaponSerialNumber` takes **no src**: `(weaponId, serial)`.
5. **Custom-inventory layer fully functional** → player-store back-room storage (D3) uses it; no
   fallback table needed. Legacy export names (`addItemInventory`, server `getInventoryItems`) do not exist.
6. **Metadata round-trip confirmed live:** `addItem` with a metadata table creates a distinct stack
   (crafted id), `subItem` with the same table removes exactly that stack. Deep-equality matching.
7. `deleteCustomInventory(id)` returned `false` in the probe (semantics unclear — possibly expects a
   cb or refuses non-empty/absent DB state). Store storages are permanent, so unused; flagged anyway.

## Verified bridge contract

```lua
local INV = exports.vorp_inventory

-- READS (synchronous returns) ------------------------------------------------
INV:getUserInventoryItems(src)          --> array of stacks:
--  { name, count, metadata, slot, percentage, isDegradable, label, id(crafted),
--    desc, canUse, limit, weight, group, type }
INV:getItemCount(src, nil, itemName)    --> number       -- cb slot 2nd: ALWAYS pass nil
INV:getItem(src, itemName)              --> stack | nil  -- nil when player holds none
INV:getItemDB(itemName)                 --> def: { item, label, limit, weight, maxDegradation,
                                        --   useExpired, canUse, canRemove, desc, metadata, group, type, id }
INV:canCarryItem(src, itemName, amount) --> boolean
INV:canCarryWeapons(src, amount, nil, weaponName) --> boolean   -- cb slot 3rd

-- ITEM WRITES ----------------------------------------------------------------
INV:addItem(src, itemName, amount)             --> boolean
INV:addItem(src, itemName, amount, metadata)   --> boolean  -- distinct stack, metadata preserved
INV:subItem(src, itemName, amount)             --> boolean
INV:subItem(src, itemName, amount, metadata)   --> boolean  -- exact-match stack only

-- WEAPONS --------------------------------------------------------------------
INV:getUserInventoryWeapons(src)  --> array: { id, name, label, serial_number, custom_label,
                                  --   custom_desc?, propietary, used, used2, ammo, group=5, source, weight }
INV:createWeapon(src, weaponName, nil, nil, {}, nil, nil, serial, customLabel, customDesc) --> boolean
--   ^ store sale call: stamps serial + label + desc atomically at creation (all three verified)
INV:createWeapon(src, weaponName)              --> boolean  -- plain; serial_number stays ""
INV:setWeaponSerialNumber(weaponId, serial)    --> boolean  -- NO src argument
INV:deleteWeapon(src, weaponId)                --> boolean
-- setWeaponCustomLabel/Desc with (src, id, …) error; not needed — use creation-time args.
-- Buying weapons FROM players: getUserInventoryWeapons → match → deleteWeapon (vorp_stores pattern).

-- CUSTOM INVENTORY (store storage) --------------------------------------------
INV:registerInventory({ id=, name=, limit=, shared=true, ignoreItemStackLimit=, whitelistItems= })
--   returns the inventory object; observed fields: useweight (lowercase!), webhook, shared, name,
--   ignoreItemStackLimit, whitelistItems, UseBlackList, BlackListItems, limitedItems, limitedWeapons,
--   PermissionMoveTo/PermissionTakeFrom, CharIdPermissionMoveTo/CharIdPermissionTakeFrom
INV:isCustomInventoryRegistered(id)                     --> boolean
INV:getCustomInventoryData(id)                          --> object (as above)
INV:addItemsToCustomInventory(id, { {name=, amount=} }, charid) --> boolean
INV:getCustomInventoryItems(id)                         --> array: { name, label, desc, metadata,
                                                        --   crafted_id, charid, amount, weight }
INV:getCustomInventoryItemCount(id, itemName, nil)      --> number
INV:removeItemFromCustomInventory(id, itemName, amount) --> boolean
INV:openInventory(src, id)       -- export exists, no error, BUT the UI did not open (owner confirmed
                                 --   on screen). Caveat: probe opened an EMPTY inventory (item was
                                 --   removed first) — untested with contents. DO NOT rely on it.
INV:closeInventory(src, id)      -- returned false (consistent with nothing being open)
INV:removeInventory(id)          -- session deregister
INV:deleteCustomInventory(id)    -- returned false in probe; avoid, treat storages as permanent
```

## Client-side (verified live)

- `LocalPlayer.state.Character` → `Money`, `Job`, `Grade`, `CharId` (PascalCase) — live money display for NUI.
- `LocalPlayer.state.IsInSession` → readiness gate.
- `exports.vorp_inventory:getInventoryItems()` (client), `getWeaponDefaultLabel(hash)`, `closeInventory()` all work.

## Database (live schema)

- Tables: `items`, `items_crafted`, `character_inventories`, `loadout`, `item_group`, `item_rarity`, `characters`.
- `loadout`: has `serial_number`, `custom_label`, `custom_desc`, `slot_position`, condition columns
  (`degradation`, `damage`, `dirt`, `soot`), `curr_inv`.
- `character_inventories`: `character_id`, `inventory_type` (custom inventories keyed here), `item_crafted_id`,
  `item_name`, `amount`, `degradation`, `percentage`, `slot_position`.
- `items_crafted`: per-stack `metadata` + `durability`.
- `characters.LastLogin` → inactivity monitor source (F4), plus `job`/`jobgrade`/`group`/`money` as mapped.

## Consequences for the design

- Bridge wrappers are thin sync functions; a single `Inv` namespace in `shared/bridge.lua`.
- Weapon sale path (player store): generate `CODE-XXXXXX` → check registry table → single
  `createWeapon(src, name, nil, nil, {}, nil, nil, serial, label, "Sold by {store} — {date}")`.
- Store storage id convention: `sovstore_<storeId>` (registered `shared=true` at boot; access controlled
  by OUR permission checks before any add/remove call — the built-in charid permission lists exist
  as a second layer if wanted).
- **Storage UI is OURS, not the native inventory UI.** `openInventory` did not open a window on the
  dev server (see contract note), so back-room storage is presented inside the store-management NUI:
  list + deposit/withdraw controls backed by the verified data APIs (`getCustomInventoryItems`,
  `addItemsToCustomInventory`, `removeItemFromCustomInventory`) plus `addItem`/`subItem` on the player
  side, all in one guarded server transaction. Optional future micro-probe: retry `openInventory` with
  contents present if native drag-drop is ever wanted.
- All 🔬 features in 02-FEATURES.md are now ✅ — see updated statuses.
