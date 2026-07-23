--[[=====================================================================
  STORE PROBE · SERVER SIDE  (TP-1)
  Confirms Cas-inventory export signatures that escrow hides.
  Everything pcall-safe; writes are paired with undo.
=====================================================================]]--

local INV = 'vorp_inventory'

-- ────────────────────────── helpers ──────────────────────────

local function say(color, text) print(('^%d[storeprobe] %s^7'):format(color, text)) end
local function head(text) print(('^5[storeprobe] ===== %s =====^7'):format(text)) end

-- shallow dump: enough to read field names + scalar values without spam
local function dump(v, depth)
    depth = depth or 0
    local t = type(v)
    if t ~= 'table' then return tostring(v) end
    if depth >= 2 then return '{...}' end
    local parts, n = {}, 0
    for k, val in pairs(v) do
        n = n + 1
        if n > 14 then parts[#parts + 1] = '…' break end
        parts[#parts + 1] = tostring(k) .. '=' .. dump(val, depth + 1)
    end
    return '{ ' .. table.concat(parts, ', ') .. ' }'
end

-- Direct call attempt: prints result (return-style probing)
local function try(label, fn)
    local ok, a, b = pcall(fn)
    if ok then
        say(2, ('YES  %s  -> (%s) %s %s'):format(label, type(a), dump(a), b ~= nil and dump(b) or ''))
        return a
    else
        say(1, ('no   %s  (%s)'):format(label, tostring(a)))
        return nil
    end
end

-- Callback attempt: invoker(cb) must place cb wherever the candidate
-- signature expects it. Reports whether cb fired within the timeout.
local function tryCb(label, invoker, timeoutMs)
    local p = promise.new()
    local settled = false
    local function settle(v) if not settled then settled = true; p:resolve(v) end end
    local ok, err = pcall(invoker, function(...)
        local n = select('#', ...)
        settle({ fired = true, n = n, first = n > 0 and select(1, ...) or nil })
    end)
    if not ok then
        say(1, ('no   %s  (call errored: %s)'):format(label, tostring(err)))
        return nil
    end
    SetTimeout(timeoutMs or 1500, function() settle({ fired = false }) end)
    local r = Citizen.Await(p)
    if r.fired then
        say(2, ('YES  %s  -> cb fired, arg1=(%s) %s'):format(label, type(r.first), dump(r.first)))
        return r.first
    else
        say(3, ('~    %s  (no error, but cb never fired — cb likely not at this position)'):format(label))
        return nil
    end
end

-- Count of ITEM in main inventory via getUserInventoryItems (order-independent baseline)
local function baselineCount(src, item)
    local ok, inv = pcall(function() return exports[INV]:getUserInventoryItems(src) end)
    if not ok or type(inv) ~= 'table' then return nil end
    local total = 0
    for _, it in pairs(inv) do
        if it and (it.name == item or it.item == item) then total = total + (it.count or it.amount or 0) end
    end
    return total
end

local function weaponIds(src)
    local ids = {}
    local ok, weps = pcall(function() return exports[INV]:getUserInventoryWeapons(src) end)
    if ok and type(weps) == 'table' then
        for _, w in pairs(weps) do if w and w.id then ids[w.id] = w end end
    end
    return ids
end

-- ────────────────────────── probe sections ──────────────────────────

local function section0_env(item)
    head('0 · ENVIRONMENT')
    say(2, 'vorp_inventory state: ' .. GetResourceState(INV))
    say(2, 'vorp_inventory version: ' .. tostring(GetResourceMetadata(INV, 'version', 0)))
    say(2, 'oxmysql state: ' .. GetResourceState('oxmysql'))

    -- validate the test item exists in the items DB table
    if GetResourceState('oxmysql') == 'started' and MySQL then
        local ok, rows = pcall(function()
            return MySQL.query.await('SELECT item, label, `limit`, degradation FROM items WHERE item = ?', { item })
        end)
        if ok and rows and rows[1] then
            say(2, ('test item ok: %s (%s) limit=%s degradation=%s'):format(item, rows[1].label, tostring(rows[1]['limit']), tostring(rows[1].degradation)))
            return true
        end
        say(1, ('test item "%s" NOT in items table — rerun as /storeprobe <item> <weapon>. Some valid names:'):format(item))
        local ok2, sample = pcall(function() return MySQL.query.await('SELECT item FROM items LIMIT 8', {}) end)
        if ok2 and sample then
            local names = {}
            for _, r in ipairs(sample) do names[#names + 1] = r.item end
            say(3, table.concat(names, ', '))
        end
        return false
    end
    say(3, 'oxmysql not available to probe — skipping item validation (probe continues)')
    return true
end

local function section1_reads(src, item)
    head('1 · READ APIS — return-style vs callback, arg order')

    local inv = try('getUserInventoryItems(src) [return]', function() return exports[INV]:getUserInventoryItems(src) end)
    if type(inv) == 'table' then
        local first
        for _, it in pairs(inv) do first = it break end
        if first then say(2, 'sample item fields: ' .. dump(first)) end
    end
    tryCb('getUserInventoryItems(src, cb)', function(cb) exports[INV]:getUserInventoryItems(src, cb) end)

    try('getItemCount(src, nil, item) [v2 order, return]', function() return exports[INV]:getItemCount(src, nil, item) end)
    try('getItemCount(src, item) [old order, return]', function() return exports[INV]:getItemCount(src, item) end)
    tryCb('getItemCount(src, cb, item) [v2 order]', function(cb) exports[INV]:getItemCount(src, cb, item) end)

    try('getItem(src, item) [return]', function() return exports[INV]:getItem(src, item) end)
    tryCb('getItem(src, item, cb)', function(cb) exports[INV]:getItem(src, item, cb) end)

    try('getItemDB(item) [return]', function() return exports[INV]:getItemDB(item) end)

    try('canCarryItem(src, item, 1) [return]', function() return exports[INV]:canCarryItem(src, item, 1) end)
    tryCb('canCarryItem(src, item, 1, cb)', function(cb) exports[INV]:canCarryItem(src, item, 1, cb) end)
end

local function section2_itemWrites(src, item)
    head('2 · ITEM WRITE + UNDO (net zero)')
    local before = baselineCount(src, item)
    say(2, ('baseline count of %s: %s'):format(item, tostring(before)))

    try('addItem(src, item, 1) [return]', function() return exports[INV]:addItem(src, item, 1) end)
    local afterAdd = baselineCount(src, item)
    say(afterAdd == (before or 0) + 1 and 2 or 3, ('count after add: %s (expected %s)'):format(tostring(afterAdd), tostring((before or 0) + 1)))

    try('subItem(src, item, 1) [return]', function() return exports[INV]:subItem(src, item, 1) end)
    local afterSub = baselineCount(src, item)
    say(afterSub == before and 2 or 1, ('count after undo: %s (expected %s)'):format(tostring(afterSub), tostring(before)))

    -- metadata stack: add with metadata, find it, remove it by metadata
    local META = { sovprobe = true, quality = 97 }
    try('addItem(src, item, 1, {sovprobe}) [metadata]', function() return exports[INV]:addItem(src, item, 1, META) end)
    local foundMeta = false
    local ok, inv = pcall(function() return exports[INV]:getUserInventoryItems(src) end)
    if ok and type(inv) == 'table' then
        for _, it in pairs(inv) do
            local m = it and it.metadata
            if type(m) == 'table' and m.sovprobe then
                foundMeta = true
                say(2, 'metadata stack found: ' .. dump(it))
                break
            end
        end
    end
    if not foundMeta then say(1, 'metadata stack NOT found via getUserInventoryItems — note this') end
    try('subItem(src, item, 1, {sovprobe}) [metadata undo]', function() return exports[INV]:subItem(src, item, 1, META) end)
    local finalCount = baselineCount(src, item)
    say(finalCount == before and 2 or 1, ('final count: %s (baseline was %s) %s'):format(
        tostring(finalCount), tostring(before), finalCount == before and '— NET ZERO OK' or '— MISMATCH, check your inventory'))
end

local function section3_weapons(src, wep)
    head('3 · WEAPONS — create/serial/label/delete (net zero)')
    local before = weaponIds(src)

    try('createWeapon(src, wep) [minimal]', function() return exports[INV]:createWeapon(src, wep) end)
    Wait(500)
    local after = weaponIds(src)
    local newId
    for id, w in pairs(after) do
        if not before[id] then
            newId = id
            say(2, 'new weapon: ' .. dump(w))
            break
        end
    end
    if newId then
        try(('setWeaponSerialNumber(src, %s, "SOV-000001")'):format(newId), function() return exports[INV]:setWeaponSerialNumber(src, newId, 'SOV-000001') end)
        try(('setWeaponSerialNumber(%s, "SOV-000002") [no src]'):format(newId), function() return exports[INV]:setWeaponSerialNumber(newId, 'SOV-000002') end)
        try(('setWeaponCustomLabel(src, %s, "Probe Label")'):format(newId), function() return exports[INV]:setWeaponCustomLabel(src, newId, 'Probe Label') end)
        try(('setWeaponCustomDesc(src, %s, "Probe Desc")'):format(newId), function() return exports[INV]:setWeaponCustomDesc(src, newId, 'Probe Desc') end)
        Wait(300)
        local check = weaponIds(src)[newId]
        if check then say(2, 'weapon after setters: ' .. dump(check)) end
        try(('deleteWeapon(src, %s) [undo]'):format(newId), function() return exports[INV]:deleteWeapon(src, newId) end)
    else
        say(1, 'could not identify the new weapon id — createWeapon may have failed (weapon cap? bad name?)')
    end

    -- creation-time custom serial (v2 arg order hypothesis)
    local before2 = weaponIds(src)
    try('createWeapon(src, wep, nil, nil, {}, nil, nil, "SOV-CREATE1", "Create Label", "Create Desc") [v2 custom-serial order]',
        function() return exports[INV]:createWeapon(src, wep, nil, nil, {}, nil, nil, 'SOV-CREATE1', 'Create Label', 'Create Desc') end)
    Wait(500)
    local after2 = weaponIds(src)
    for id, w in pairs(after2) do
        if not before2[id] then
            say(2, 'custom-serial weapon result (check serial_number/custom_label fields!): ' .. dump(w))
            try(('deleteWeapon(src, %s) [undo]'):format(id), function() return exports[INV]:deleteWeapon(src, id) end)
            break
        end
    end

    try('canCarryWeapons(src, 1, nil, wep) [return]', function() return exports[INV]:canCarryWeapons(src, 1, nil, wep) end)
    tryCb('canCarryWeapons(src, 1, cb, wep)', function(cb) exports[INV]:canCarryWeapons(src, 1, cb, wep) end)
end

local function section4_customInv(src, item)
    head('4 · CUSTOM INVENTORY (store storage path)')
    local ID = 'sovprobe_storage'
    local charid
    pcall(function()
        local Core = exports.vorp_core:GetCore()
        charid = Core.getUser(src).getUsedCharacter.charIdentifier
    end)
    say(2, 'charIdentifier: ' .. tostring(charid))

    try('registerInventory({id, name, limit, shared, ignoreItemStackLimit})', function()
        return exports[INV]:registerInventory({
            id = ID, name = 'Probe Storage', limit = 10,
            shared = true, ignoreItemStackLimit = true, whitelistItems = false,
        })
    end)
    try('isCustomInventoryRegistered(id)', function() return exports[INV]:isCustomInventoryRegistered(ID) end)
    try('getCustomInventoryData(id)', function() return exports[INV]:getCustomInventoryData(ID) end)
    try('addItemsToCustomInventory(id, {{name,amount}}, charid)', function()
        return exports[INV]:addItemsToCustomInventory(ID, { { name = item, amount = 1 } }, charid)
    end)
    try('getCustomInventoryItems(id)', function() return exports[INV]:getCustomInventoryItems(ID) end)
    try('getCustomInventoryItemCount(id, item, nil)', function() return exports[INV]:getCustomInventoryItemCount(ID, item, nil) end)
    try('removeItemFromCustomInventory(id, item, 1)', function() return exports[INV]:removeItemFromCustomInventory(ID, item, 1) end)
    -- legacy-name fallbacks some forks kept:
    try('[legacy] addItemInventory(...)', function() return exports[INV]:addItemInventory(src, ID, item, 1) end)
    try('[legacy] getInventoryItems(id) [server]', function() return exports[INV]:getInventoryItems(ID) end)

    say(3, 'opening the custom inventory UI for you now — note in your reply whether it opened…')
    try('openInventory(src, id)', function() return exports[INV]:openInventory(src, ID) end)
    Wait(2500)
    try('closeInventory(src, id)', function() return exports[INV]:closeInventory(src, ID) end)

    try('deleteCustomInventory(id) [cleanup]', function() return exports[INV]:deleteCustomInventory(ID) end)
    try('removeInventory(id) [cleanup]', function() return exports[INV]:removeInventory(ID) end)
end

local function section5_db()
    head('5 · DATABASE (read-only)')
    if GetResourceState('oxmysql') ~= 'started' or not MySQL then
        say(1, 'oxmysql unavailable — skipping')
        return
    end
    local ok, rows = pcall(function() return MySQL.query.await('SHOW TABLES', {}) end)
    if ok and rows then
        local interesting = {}
        for _, r in ipairs(rows) do
            for _, name in pairs(r) do
                local n = tostring(name):lower()
                if n:find('item') or n:find('inventor') or n:find('loadout') or n:find('stash') or n:find('bag') or n:find('character') then
                    interesting[#interesting + 1] = name
                end
            end
        end
        say(2, 'inventory-adjacent tables: ' .. table.concat(interesting, ', '))
    end
    for _, tbl in ipairs({ 'loadout', 'items', 'character_inventories', 'items_crafted', 'characters' }) do
        local ok2, cols = pcall(function() return MySQL.query.await('SHOW COLUMNS FROM `' .. tbl .. '`', {}) end)
        if ok2 and cols then
            local names = {}
            for _, c in ipairs(cols) do names[#names + 1] = c.Field end
            say(2, tbl .. ' columns: ' .. table.concat(names, ', '))
        else
            say(3, tbl .. ': not present under this name')
        end
    end
end

-- ────────────────────────── entry point ──────────────────────────

local running = false

RegisterCommand('storeprobe', function(source, args)
    if running then return say(1, 'probe already running') end
    local src = source
    if src == 0 then
        src = tonumber(GetPlayers()[1] or 0)
        if not src or src == 0 then return say(1, 'need at least one player connected') end
    end
    local item = args[1] or 'water'
    local wep  = args[2] or 'WEAPON_MELEE_KNIFE'

    running = true
    CreateThread(function()
        head(('PROBE START · player %s · item %s · weapon %s'):format(src, item, wep))
        local proceed = section0_env(item)
        if proceed then
            section1_reads(src, item)
            section2_itemWrites(src, item)
            section3_weapons(src, wep)
            section4_customInv(src, item)
        end
        section5_db()
        head('PROBE DONE — copy everything between the ===== marks (plus client block) to Claude')
        TriggerClientEvent('sovereign_storeprobe:client', src)
        running = false
    end)
end, false)

-- client results echo here so everything lands in one console
RegisterNetEvent('sovereign_storeprobe:results', function(lines)
    head('CLIENT RESULTS (player ' .. tostring(source) .. ')')
    for _, line in ipairs(lines or {}) do print('[storeprobe][client] ' .. line) end
    head('END CLIENT RESULTS')
end)
