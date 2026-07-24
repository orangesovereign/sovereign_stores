--[[=====================================================================
  SOVEREIGN STORES · STORE MANAGEMENT — server side (docs/04 screen 2)
  Owner/co-owner/employee operations. Every callback resolves the
  caller's role fresh; the NUI is presentation only.
=====================================================================]]--

local function todayStats(storeId)
    local rows = Db.query(
        [[SELECT COALESCE(SUM(CASE WHEN type = 'sale' THEN amount END), 0) AS sales,
                 COALESCE(SUM(CASE WHEN type = 'sale' THEN 1 END), 0) AS orders
          FROM sovereign_store_ledger
          WHERE store_id = ? AND account = 'operating' AND created_at >= CURDATE()]], { storeId })
    local r = rows and rows[1] or {}
    return { sales = Util.round2(tonumber(r.sales) or 0), orders = tonumber(r.orders) or 0 }
end

local function weekBars(storeId)
    local rows = Db.query(
        [[SELECT DATE(created_at) AS d,
                 COALESCE(SUM(CASE WHEN type = 'sale' THEN amount ELSE 0 END), 0) AS gross,
                 COALESCE(SUM(CASE WHEN type = 'purchase' THEN -amount ELSE 0 END), 0) AS payouts
          FROM sovereign_store_ledger
          WHERE store_id = ? AND account = 'operating' AND created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
          GROUP BY DATE(created_at) ORDER BY d]], { storeId }) or {}
    local byDay = {}
    for _, r in ipairs(rows) do byDay[tostring(r.d)] = r end
    local bars, gross, payouts = {}, 0, 0
    for i = 6, 0, -1 do
        local d = Db.scalar('SELECT DATE_SUB(CURDATE(), INTERVAL ? DAY)', { i })
        local key = tostring(d)
        local r = byDay[key]
        local g = Util.round2(r and tonumber(r.gross) or 0)
        local p = Util.round2(r and tonumber(r.payouts) or 0)
        gross, payouts = Util.round2(gross + g), Util.round2(payouts + p)
        bars[#bars + 1] = { day = key:sub(6), gross = g }
    end
    return { bars = bars, gross = gross, payouts = payouts, net = Util.round2(gross - payouts) }
end

local function charName(charid)
    local rows = Db.query('SELECT firstname, lastname FROM characters WHERE charidentifier = ?', { charid })
    local r = rows and rows[1]
    return r and ('%s %s'):format(r.firstname or '?', r.lastname or '?') or ('#' .. tostring(charid))
end

local function mgmtPayload(src, storeId)
    local s = PStores.get(storeId)
    local charid = Bridge.getCharId(src)
    local role = PStores.roleOf(storeId, charid)
    if not s or not role then return { ok = false, error = 'not_staff' } end

    local staff = {}
    if s.coowner_charid then
        staff[#staff + 1] = { role = 'coowner', charid = s.coowner_charid, name = charName(s.coowner_charid), permissions = Perms.ALL }
    end
    for _, e in ipairs(PStores.staff(storeId)) do
        staff[#staff + 1] = {
            role = 'employee', charid = e.charid, name = charName(e.charid),
            permissions = e.permissions, payModel = e.pay_model, payRate = e.pay_rate,
        }
    end

    local myPerms = Perms.ALL
    if role == 'employee' then
        for _, e in ipairs(PStores.staff(storeId)) do
            if e.charid == charid then myPerms = Perms.clean(e.permissions) end
        end
    end

    return {
        ok = true,
        me = { charid = charid, role = role, permissions = myPerms, name = charName(charid) },
        store = {
            id = s.id, code = s.code, name = s.name, category = s.category, status = s.status,
            ownerName = s.owner_charid and charName(s.owner_charid) or nil,
            branding = s.branding,
            balances = { operating = Ledger.balance(s.id, 'operating'), tax = Ledger.balance(s.id, 'tax') },
            taxRate = s.tax_rate, purchasePrice = s.purchase_price,
            taxState = s.tax_state, taxDue = s.tax_due_date,
        },
        today = todayStats(s.id),
        week = weekBars(s.id),
        stock = Stock.list(s.id),
        storage = Bridge.storage.items(s.id),
        staff = staff,
        maxEmployees = Config.MaxEmployees,
        ledger = Ledger.history(s.id, 'operating', 20),
        taxLedger = Ledger.history(s.id, 'tax', 8),
    }
end

-- ── Actions ─────────────────────────────────────────────────────────
-- Each returns ok:boolean, err:string|nil. `charid` is the caller.

local ACTIONS = {}

-- storefront (STOREFRONT flag)
ACTIONS.set_status = function(s, src, charid, p)
    if not PStores.can(s.id, charid, Perms.STOREFRONT) then return false, 'no_permission' end
    return PStores.setStatus(s.id, p.open == true, charid)
end
ACTIONS.rename = function(s, src, charid, p)
    if not PStores.can(s.id, charid, Perms.STOREFRONT) then return false, 'no_permission' end
    return PStores.rename(s.id, p.name, charid)
end
ACTIONS.branding = function(s, src, charid, p)
    if not PStores.can(s.id, charid, Perms.STOREFRONT) then return false, 'no_permission' end
    return PStores.setBranding(s.id, p or {}, charid)
end

-- funds
ACTIONS.deposit = function(s, src, charid, p)
    return PStores.deposit(s.id, src, p.account, tonumber(p.amount))
end
ACTIONS.withdraw = function(s, src, charid, p)
    return PStores.withdraw(s.id, src, tonumber(p.amount))
end

-- roster (owner / co-owner only)
local function isBoss(s, charid)
    local role = PStores.roleOf(s.id, charid)
    return role == 'owner' or role == 'coowner'
end
ACTIONS.hire = function(s, src, charid, p)
    if not isBoss(s, charid) then return false, 'no_permission' end
    return PStores.hire(s.id, tonumber(p.charid), tonumber(p.permissions) or 0, p.payModel, tonumber(p.payRate) or 0, charid)
end
ACTIONS.fire = function(s, src, charid, p)
    if not isBoss(s, charid) then return false, 'no_permission' end
    if tonumber(p.charid) == s.owner_charid then return false, 'not_the_owner' end
    return PStores.fire(s.id, tonumber(p.charid), charid)
end
ACTIONS.set_employee = function(s, src, charid, p)
    if not isBoss(s, charid) then return false, 'no_permission' end
    return PStores.setEmployee(s.id, tonumber(p.charid), tonumber(p.permissions), p.payModel, tonumber(p.payRate), charid)
end
ACTIONS.set_coowner = function(s, src, charid, p)
    if PStores.roleOf(s.id, charid) ~= 'owner' then return false, 'no_permission' end
    return PStores.setCoOwner(s.id, p.charid and tonumber(p.charid) or nil, charid)
end

-- stock & storage (STOCK / PRICES flags)
ACTIONS.shelve = function(s, src, charid, p)
    if not PStores.can(s.id, charid, Perms.STOCK) then return false, 'no_permission' end
    return Stock.shelve(s.id, tostring(p.item), p.qty, p.price, p.category)
end
ACTIONS.unshelve = function(s, src, charid, p)
    if not PStores.can(s.id, charid, Perms.STOCK) then return false, 'no_permission' end
    return Stock.unshelve(s.id, tostring(p.item), p.qty, charid)
end
ACTIONS.set_price = function(s, src, charid, p)
    if not PStores.can(s.id, charid, Perms.PRICES) then return false, 'no_permission' end
    return Stock.setPrice(s.id, tostring(p.item), p.price)
end
ACTIONS.set_sale = function(s, src, charid, p)
    if not PStores.can(s.id, charid, Perms.PRICES) then return false, 'no_permission' end
    return Stock.setSale(s.id, tostring(p.item), p.percent, p.minutes)
end
ACTIONS.clear_sale = function(s, src, charid, p)
    if not PStores.can(s.id, charid, Perms.PRICES) then return false, 'no_permission' end
    return Stock.clearSale(s.id, tostring(p.item))
end

-- back room ↔ player satchel (STOCK flag)
ACTIONS.storage_deposit = function(s, src, charid, p)
    if not PStores.can(s.id, charid, Perms.STOCK) then return false, 'no_permission' end
    local item, qty = tostring(p.item), math.floor(tonumber(p.qty) or 0)
    if qty < 1 then return false, 'bad_input' end
    if Bridge.inv.count(src, item) < qty then return false, 'not_carried' end
    if not Bridge.inv.sub(src, item, qty) then return false, 'sub_failed' end
    if not Bridge.storage.addItems(s.id, { { name = item, amount = qty } }, charid) then
        Bridge.inv.add(src, item, qty)   -- put it back, never eat goods
        return false, 'storage_refused'
    end
    return true
end
ACTIONS.storage_take = function(s, src, charid, p)
    if not PStores.can(s.id, charid, Perms.STOCK) then return false, 'no_permission' end
    local item, qty = tostring(p.item), math.floor(tonumber(p.qty) or 0)
    if qty < 1 then return false, 'bad_input' end
    if Bridge.storage.count(s.id, item) < qty then return false, 'not_in_storage' end
    if not Bridge.inv.canCarry(src, item, qty) then return false, 'cant_carry' end
    if not Bridge.storage.removeItem(s.id, item, qty) then return false, 'storage_refused' end
    if not Bridge.inv.add(src, item, qty) then
        Bridge.storage.addItems(s.id, { { name = item, amount = qty } }, charid)
        return false, 'add_failed'
    end
    return true
end

-- ── Callbacks + command ─────────────────────────────────────────────

CreateThread(function()
    while not Bridge.core() do Wait(250) end
    local C = Bridge.core()

    C.Callback.Register('sovereign_stores:mgmt:get', function(source, cb, storeId)
        cb(mgmtPayload(source, tonumber(storeId)))
    end)

    C.Callback.Register('sovereign_stores:mgmt:action', function(source, cb, storeId, action, payload)
        local s = PStores.get(tonumber(storeId))
        local charid = Bridge.getCharId(source)
        if not s or not charid or not PStores.isStaff(s.id, charid) then
            return cb({ ok = false, error = 'not_staff' })
        end
        local fn = ACTIONS[tostring(action)]
        if not fn then return cb({ ok = false, error = 'bad_action' }) end
        local ok, err = fn(s, source, charid, payload or {})
        cb({ ok = ok == true, error = err })
    end)

    C.Callback.Register('sovereign_stores:mgmt:findCharacter', function(source, cb, query)
        local charid = Bridge.getCharId(source)
        -- staff anywhere may search (hire flow); results are name+id only
        if not charid then return cb({ ok = false, error = 'no_char' }) end
        query = tostring(query or ''):gsub('[%%_]', '')
        if #query < 2 then return cb({ ok = true, results = {} }) end
        local rows = Db.query(
            [[SELECT charidentifier, firstname, lastname FROM characters
              WHERE CONCAT(firstname, ' ', lastname) LIKE ? ORDER BY LastLogin DESC LIMIT 8]],
            { '%' .. query .. '%' }) or {}
        local results = {}
        for _, r in ipairs(rows) do
            results[#results + 1] = { charid = r.charidentifier, name = ('%s %s'):format(r.firstname or '?', r.lastname or '?') }
        end
        cb({ ok = true, results = results })
    end)

    -- which stores am I staff at? (client uses this to offer the panel)
    C.Callback.Register('sovereign_stores:mgmt:myStores', function(source, cb)
        local charid = Bridge.getCharId(source)
        local mine = {}
        if charid then
            for id, s in pairs(PStores.all()) do
                local role = PStores.roleOf(id, charid)
                if role then mine[#mine + 1] = { id = id, name = s.name, code = s.code, role = role, status = s.status } end
            end
        end
        cb({ ok = true, stores = mine })
    end)
end)

-- /mystore opens the management panel (staff-gated server-side).
RegisterCommand('mystore', function(source)
    if source == 0 then return Util.warn('mystore is an in-game command') end
    local charid = Bridge.getCharId(source)
    if not charid then return end
    for id in pairs(PStores.all()) do
        if PStores.roleOf(id, charid) then
            return TriggerClientEvent('sovereign_stores:openManagement', source)
        end
    end
    Bridge.notify(source, _U('err_not_staff'))
end, false)
