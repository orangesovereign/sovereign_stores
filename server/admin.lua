--[[=====================================================================
  SOVEREIGN STORES · COMMERCE BUREAU — server side (features H1-H3, H8)
  Every callback re-checks Bridge.isAdmin. The NUI is presentation only.
=====================================================================]]--

local function charInfo(charid)
    if not charid then return nil end
    local rows = Db.query(
        'SELECT firstname, lastname, LastLogin FROM characters WHERE charidentifier = ?', { charid })
    local r = rows and rows[1]
    if not r then return { charid = charid, name = ('#%s'):format(charid), lastLogin = nil } end
    return {
        charid = charid,
        name = ('%s %s'):format(r.firstname or '?', r.lastname or '?'),
        lastLogin = r.LastLogin,
    }
end

local function directoryRows()
    local out = {}
    for id, s in pairs(PStores.all()) do
        local owner = s.owner_charid and charInfo(s.owner_charid) or nil
        local flag = 'none'
        if s.status ~= 'repossessed' and s.tax_state == 'delinquent' then flag = 'tax_delinquent' end
        out[#out + 1] = {
            id = id, code = s.code, name = s.name, category = s.category,
            status = s.status, flag = flag,
            owner = owner and owner.name or nil,
            ownerCharid = s.owner_charid,
            lastLogin = owner and owner.lastLogin or nil,
        }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function overview()
    local stores, open, delinquent = 0, 0, 0
    for _, s in pairs(PStores.all()) do
        stores = stores + 1
        if s.status == 'open' then open = open + 1 end
        if s.tax_state == 'delinquent' then delinquent = delinquent + 1 end
    end
    return {
        ok = true,
        tiles = {
            stores = stores, open = open,
            fund = Fund.balance(),
            delinquent = delinquent,
            inactivityFlags = 0,   -- populated by the Phase 4 inactivity scheduler
        },
        directory = directoryRows(),
    }
end

local function storeDetail(id)
    local s = PStores.get(id)
    if not s then return { ok = false, error = 'unknown' } end
    local staff = {}
    if s.coowner_charid then
        local info = charInfo(s.coowner_charid)
        staff[#staff + 1] = { role = 'coowner', charid = s.coowner_charid, name = info.name, permissions = Perms.ALL }
    end
    for _, e in ipairs(PStores.staff(id)) do
        local info = charInfo(e.charid)
        staff[#staff + 1] = {
            role = 'employee', charid = e.charid, name = info.name,
            permissions = e.permissions, permLabels = Perms.list(e.permissions),
            payModel = e.pay_model, payRate = e.pay_rate,
        }
    end
    local owner = s.owner_charid and charInfo(s.owner_charid) or nil
    return {
        ok = true,
        store = {
            id = s.id, code = s.code, name = s.name, category = s.category, status = s.status,
            owner = owner, coownerCharid = s.coowner_charid,
            purchasePrice = s.purchase_price, taxRate = s.tax_rate,
            taxState = s.tax_state, taxDue = s.tax_due_date,
            inactivityExemptUntil = s.inactivity_exempt_until,
            branding = s.branding, registerCoords = s.register_coords,
            balances = {
                operating = Ledger.balance(s.id, 'operating'),
                tax = Ledger.balance(s.id, 'tax'),
            },
        },
        staff = staff,
        ledger = Ledger.history(s.id, 'operating', 25),
        taxLedger = Ledger.history(s.id, 'tax', 10),
        events = EventLog.recent(s.id, 25),
        storage = Bridge.storage.items(s.id),
    }
end

local ACTIONS = {
    assign_owner = function(s, p, actor) return PStores.assignOwner(s.id, tonumber(p.charid), actor) end,
    transfer     = function(s, p, actor) return PStores.transferOwner(s.id, tonumber(p.charid), actor) end,
    set_code     = function(s, p, actor) return PStores.setCode(s.id, p.code, actor) end,
    set_price    = function(s, p, actor) return PStores.setPurchasePrice(s.id, tonumber(p.price), actor) end,
    set_tax_rate = function(s, p, actor) return PStores.setTaxRate(s.id, tonumber(p.rate), actor) end,
    repossess    = function(s, p, actor) return PStores.repossess(s.id, p.reason or 'admin repossession', actor) end,
    force_close  = function(s, _, actor) return PStores.setStatus(s.id, false, actor) end,
    exempt_inactivity = function(s, p, actor) return PStores.setInactivityExempt(s.id, p.untilDate, actor) end,
    adjust = function(s, p, actor)
        local amount = Util.round2(tonumber(p.amount) or 0)
        local account = (p.account == 'tax') and 'tax' or 'operating'
        if amount == 0 then return false, 'bad_amount' end
        local ok = Ledger.write(s.id, account, 'adjustment', amount, { actor = actor, note = p.note or 'admin adjustment' })
        if ok then EventLog.write(s.id, 'adjustment', actor, nil, { account = account, amount = amount, note = p.note }) end
        return ok, ok and nil or 'insufficient'
    end,
}

CreateThread(function()
    while not Bridge.core() do Wait(250) end
    local C = Bridge.core()

    local function guarded(name, fn)
        C.Callback.Register(name, function(source, cb, ...)
            if not Bridge.isAdmin(source) then return cb({ ok = false, error = 'no_permission' }) end
            cb(fn(source, ...))
        end)
    end

    guarded('sovereign_stores:admin:overview', function() return overview() end)
    guarded('sovereign_stores:admin:store', function(_, id) return storeDetail(tonumber(id)) end)

    guarded('sovereign_stores:admin:create', function(source, data)
        if type(data) ~= 'table' or type(data.name) ~= 'string' or #data.name < 3 then
            return { ok = false, error = 'bad_name' }
        end
        local actor = Bridge.getCharId(source)
        local id, err = PStores.create({
            name = data.name:sub(1, 48), category = data.category,
            coords = data.coords, npcModel = data.npcModel,
        }, actor)
        if not id then return { ok = false, error = err } end
        if data.code and data.code ~= '' then
            local okCode, codeErr = PStores.setCode(id, data.code, actor)
            if not okCode then return { ok = true, id = id, warning = codeErr } end
        end
        if tonumber(data.price) then PStores.setPurchasePrice(id, tonumber(data.price), actor) end
        if tonumber(data.rate) then PStores.setTaxRate(id, tonumber(data.rate), actor) end
        if tonumber(data.ownerCharid) then PStores.assignOwner(id, tonumber(data.ownerCharid), actor) end
        return { ok = true, id = id }
    end)

    guarded('sovereign_stores:admin:action', function(source, id, action, payload)
        local s = PStores.get(tonumber(id))
        if not s then return { ok = false, error = 'unknown' } end
        local fn = ACTIONS[tostring(action)]
        if not fn then return { ok = false, error = 'bad_action' } end
        local ok, err = fn(s, payload or {}, Bridge.getCharId(source))
        return { ok = ok == true, error = err }
    end)

    guarded('sovereign_stores:admin:findCharacter', function(_, query)
        query = tostring(query or ''):gsub('[%%_]', '')
        if #query < 2 then return { ok = true, results = {} } end
        local rows = Db.query(
            [[SELECT charidentifier, firstname, lastname, LastLogin FROM characters
              WHERE CONCAT(firstname, ' ', lastname) LIKE ? ORDER BY LastLogin DESC LIMIT 8]],
            { '%' .. query .. '%' }) or {}
        local results = {}
        for _, r in ipairs(rows) do
            results[#results + 1] = {
                charid = r.charidentifier,
                name = ('%s %s'):format(r.firstname or '?', r.lastname or '?'),
                lastLogin = r.LastLogin,
            }
        end
        return { ok = true, results = results }
    end)

    guarded('sovereign_stores:admin:fund', function()
        return {
            ok = true, balance = Fund.balance(),
            history = Db.query(
                'SELECT type, amount, balance_after, ref_store_id, note, created_at FROM sovereign_government_fund ORDER BY id DESC LIMIT 40',
                {}) or {},
        }
    end)

    guarded('sovereign_stores:admin:events', function()
        return {
            ok = true,
            events = Db.query(
                [[SELECT e.store_id, e.kind, e.actor_charid, e.target_charid, e.data, e.created_at, s.name AS store_name
                  FROM sovereign_store_events e LEFT JOIN sovereign_stores s ON s.id = e.store_id
                  ORDER BY e.id DESC LIMIT 60]], {}) or {},
        }
    end)
end)

-- The Bureau opens from a command (admin-gated server-side).
RegisterCommand('storeadmin', function(source)
    if source == 0 then return Util.warn('storeadmin is an in-game command') end
    if not Bridge.isAdmin(source) then
        return Bridge.notify(source, _U('err_no_permission'))
    end
    TriggerClientEvent('sovereign_stores:openAdmin', source)
end, false)
