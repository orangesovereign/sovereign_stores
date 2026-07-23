--[[=====================================================================
  SOVEREIGN STORES · BRIDGE
  The single choke point for every external resource. Feature code never
  names another resource — it calls Bridge.

  Inventory signatures follow docs/05-PROBE-RESULTS.md (TP-1, verified
  live against Cas-inventory 1.7.3 on 2026-07-23). Do not "fix" argument
  orders here without re-probing: getItemCount's callback slot really is
  the 2nd parameter, and setWeaponSerialNumber really takes no src.
=====================================================================]]--

Bridge = {}

local IS_SERVER <const> = IsDuplicityVersion()
local INV <const> = 'vorp_inventory'

Bridge.required = { 'vorp_core', 'vorp_inventory', 'sovereign_notify', 'sovereign_menus' }
Bridge.optional = { 'sovereign_postoffice' }   -- mail; letters queue if absent

-- ── Core acquisition (lazy, cached) ─────────────────────────────────

local Core = nil
function Bridge.core()
    if Core == nil then
        local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
        Core = (ok and c) and c or false
    end
    return Core or nil
end

function Bridge.checkDependencies()
    local report = {}
    for _, name in ipairs(Bridge.required) do
        report[#report + 1] = { name = name, state = GetResourceState(name), required = true }
    end
    for _, name in ipairs(Bridge.optional) do
        report[#report + 1] = { name = name, state = GetResourceState(name), required = false }
    end
    return report
end

-- ════════════════════════════ SERVER ═══════════════════════════════
if IS_SERVER then

    -- ── Characters ──────────────────────────────────────────────────
    function Bridge.getUser(src)
        local core = Bridge.core()
        return core and core.getUser(src) or nil
    end

    -- NOTE: getUsedCharacter / getGroup are FIELDS on the user, not methods
    function Bridge.getCharacter(src)
        local user = Bridge.getUser(src)
        return user and user.getUsedCharacter or nil
    end

    function Bridge.getCharId(src)
        local ch = Bridge.getCharacter(src)
        return ch and ch.charIdentifier or nil
    end

    function Bridge.charName(src)
        local ch = Bridge.getCharacter(src)
        if not ch then return 'Unknown' end
        return ('%s %s'):format(ch.firstname or '?', ch.lastname or '?')
    end

    -- ── Admin gate ──────────────────────────────────────────────────
    function Bridge.isAdmin(src)
        if src == 0 then return true end -- server console
        local user = Bridge.getUser(src)
        if user then
            local group = user.getGroup
            for _, allowed in ipairs(Config.AdminGroups) do
                if group == allowed then return true end
            end
        end
        return IsPlayerAceAllowed(src, Config.AdminAce)
    end

    -- ── Money seam (cash only for v1 — owner decision 2026-07-23) ──
    -- When the bank script lands, v2 wires it in HERE and nowhere else.
    Bridge.money = {}

    function Bridge.money.get(src)
        local ch = Bridge.getCharacter(src)
        return ch and Util.round2(ch.money) or 0
    end

    function Bridge.money.canAfford(src, amount)
        return Bridge.money.get(src) >= Util.round2(amount)
    end

    function Bridge.money.remove(src, amount)
        local ch = Bridge.getCharacter(src)
        if not ch then return false end
        amount = Util.round2(amount)
        if amount <= 0 then return amount == 0 end
        if ch.money < amount then return false end
        ch.removeCurrency(0, amount)   -- 0 = cash
        return true
    end

    function Bridge.money.add(src, amount)
        local ch = Bridge.getCharacter(src)
        if not ch then return false end
        amount = Util.round2(amount)
        if amount <= 0 then return amount == 0 end
        ch.addCurrency(0, amount)      -- 0 = cash
        return true
    end

    -- ── Inventory: items (sync returns, verified) ───────────────────
    Bridge.inv = {}

    function Bridge.inv.getAll(src)
        local ok, items = pcall(function() return exports[INV]:getUserInventoryItems(src) end)
        return ok and items or {}
    end

    function Bridge.inv.count(src, item)
        -- cb slot is the 2ND argument in this fork: always pass nil there
        local ok, n = pcall(function() return exports[INV]:getItemCount(src, nil, item) end)
        return ok and tonumber(n) or 0
    end

    function Bridge.inv.get(src, item)
        local ok, res = pcall(function() return exports[INV]:getItem(src, item) end)
        return ok and res or nil
    end

    function Bridge.inv.getDef(item)
        local ok, def = pcall(function() return exports[INV]:getItemDB(item) end)
        return ok and def or nil
    end

    function Bridge.inv.canCarry(src, item, amount)
        local ok, res = pcall(function() return exports[INV]:canCarryItem(src, item, amount) end)
        return ok and res == true
    end

    function Bridge.inv.add(src, item, amount, metadata)
        local ok, res = pcall(function() return exports[INV]:addItem(src, item, amount, metadata) end)
        return ok and res == true
    end

    function Bridge.inv.sub(src, item, amount, metadata)
        local ok, res = pcall(function() return exports[INV]:subItem(src, item, amount, metadata) end)
        return ok and res == true
    end

    -- ── Inventory: weapons (verified) ───────────────────────────────
    Bridge.weapons = {}

    function Bridge.weapons.getAll(src)
        local ok, weps = pcall(function() return exports[INV]:getUserInventoryWeapons(src) end)
        return ok and weps or {}
    end

    function Bridge.weapons.canCarry(src, amount, weaponName)
        -- cb slot is the 3RD argument: pass nil there
        local ok, res = pcall(function() return exports[INV]:canCarryWeapons(src, amount, nil, weaponName) end)
        return ok and res == true
    end

    -- Store-sale creation: stamps serial + label + description atomically.
    -- Verified v2 arg order: (src, name, ammo, _, comps, cb, wepId, serial, label, desc)
    function Bridge.weapons.createStamped(src, weaponName, serial, label, desc)
        local ok, res = pcall(function()
            return exports[INV]:createWeapon(src, weaponName, nil, nil, {}, nil, nil, serial, label, desc)
        end)
        return ok and res == true
    end

    function Bridge.weapons.delete(src, weaponId)
        local ok, res = pcall(function() return exports[INV]:deleteWeapon(src, weaponId) end)
        return ok and res == true
    end

    function Bridge.weapons.setSerial(weaponId, serial)
        -- verified: NO src argument on this one
        local ok, res = pcall(function() return exports[INV]:setWeaponSerialNumber(weaponId, serial) end)
        return ok and res == true
    end

    -- ── Inventory: store storage (custom-inventory DATA layer) ──────
    -- The native open UI does NOT work on this fork (see docs/05) — storage
    -- is always presented through our own NUI, backed by these calls.
    Bridge.storage = {}

    function Bridge.storage.idFor(storeId)
        return ('%s%d'):format(Config.StorageIdPrefix, storeId)
    end

    function Bridge.storage.register(storeId, label, slots)
        local ok = pcall(function()
            exports[INV]:registerInventory({
                id = Bridge.storage.idFor(storeId),
                name = label or ('Store %d Storage'):format(storeId),
                limit = slots or Config.StorageSlots,
                shared = true,
                ignoreItemStackLimit = true,
                whitelistItems = false,
            })
        end)
        return ok
    end

    function Bridge.storage.isRegistered(storeId)
        local ok, res = pcall(function()
            return exports[INV]:isCustomInventoryRegistered(Bridge.storage.idFor(storeId))
        end)
        return ok and res == true
    end

    function Bridge.storage.items(storeId)
        local ok, items = pcall(function()
            return exports[INV]:getCustomInventoryItems(Bridge.storage.idFor(storeId))
        end)
        return ok and items or {}
    end

    function Bridge.storage.count(storeId, item)
        local ok, n = pcall(function()
            return exports[INV]:getCustomInventoryItemCount(Bridge.storage.idFor(storeId), item, nil)
        end)
        return ok and tonumber(n) or 0
    end

    function Bridge.storage.addItems(storeId, items, charid)
        -- items = { { name=, amount= }, ... }
        local ok, res = pcall(function()
            return exports[INV]:addItemsToCustomInventory(Bridge.storage.idFor(storeId), items, charid)
        end)
        return ok and res == true
    end

    function Bridge.storage.removeItem(storeId, item, amount)
        local ok, res = pcall(function()
            return exports[INV]:removeItemFromCustomInventory(Bridge.storage.idFor(storeId), item, amount)
        end)
        return ok and res == true
    end

    -- ── Notifications (server → player) ─────────────────────────────
    function Bridge.notify(src, text)
        pcall(function() exports.sovereign_notify:Tick(src, text) end)
    end

    function Bridge.notifyCard(src, variant, title, body)
        pcall(function() exports.sovereign_notify:Card(src, variant, title or Config.NotifyTitle, body) end)
    end

    function Bridge.notifyObjective(src, text)
        pcall(function() exports.sovereign_notify:Objective(src, text) end)
    end

    -- ── Mail (sovereign_postoffice; stub-aware) ─────────────────────
    Bridge.mail = {}

    function Bridge.mail.available()
        if GetResourceState('sovereign_postoffice') ~= 'started' then return false end
        local ok, booted = pcall(function() return exports.sovereign_postoffice:isBooted() end)
        return ok and booted == true
    end

    -- Returns ok:boolean, result (mail id or error key e.g. 'not_implemented').
    -- Callers (Phase 4 tax letters) queue to sovereign_store_letters on failure.
    function Bridge.mail.send(opts)
        if not Bridge.mail.available() then return false, 'unavailable' end
        local ok, sent, res = pcall(function() return exports.sovereign_postoffice:SendMail(opts) end)
        if not ok then return false, 'error' end
        return sent, res
    end

    function Bridge.mail.boxFor(charid)
        if GetResourceState('sovereign_postoffice') ~= 'started' then return nil end
        local ok, box = pcall(function() return exports.sovereign_postoffice:GetBoxForCharacter(charid) end)
        return ok and box or nil
    end
end

-- ════════════════════════════ CLIENT ═══════════════════════════════
if not IS_SERVER then

    -- character statebag (PascalCase fields: Money, Job, Grade, CharId…)
    function Bridge.character()
        return LocalPlayer.state.Character
    end

    function Bridge.ready()
        return LocalPlayer.state.IsInSession == true
    end

    function Bridge.notify(text)
        pcall(function() exports.sovereign_notify:Tick(text) end)
    end

    function Bridge.notifyCard(variant, title, body)
        pcall(function() exports.sovereign_notify:Card(variant, title or Config.NotifyTitle, body) end)
    end

    -- sovereign_menus: light list menus for register interactions
    function Bridge.openMenu(def, onSelect, onClose)
        local ok, res = pcall(function() return exports.sovereign_menus:Open(def, onSelect, onClose) end)
        return ok and res == true
    end

    function Bridge.closeMenu()
        pcall(function() exports.sovereign_menus:Close() end)
    end

    function Bridge.menuOpen()
        local ok, res = pcall(function() return exports.sovereign_menus:IsOpen() end)
        return ok and res == true
    end

    function Bridge.closePlayerInventory()
        pcall(function() exports[INV]:closeInventory() end)
    end
end
