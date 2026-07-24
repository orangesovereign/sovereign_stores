--[[=====================================================================
  SOVEREIGN STORES · PLAYER STORE ENTITY (features D1/D2/D6/D7, E1)
  The ownership core: rows in sovereign_stores (class='player'), roster
  in sovereign_store_employees. Admin creates/assigns via the Commerce
  Bureau (H3); owners run their store via the Management panel.

  Roles: owner > co-owner (all perms, can't transfer) > employees
  (bitfield, shared/perms.lua). Ownership transfer is ADMIN-ONLY.
=====================================================================]]--

PStores = {}

local cache = {}    -- [id] = store row (decoded)
local roster = {}   -- [id] = { {charid, permissions, pay_model, pay_rate, hired_at}, ... }

-- placements refresh (blips appear/disappear with status, names update live)
local function republish()
    if Npc and Npc.publishAll then Npc.publishAll() end
end

-- ── Load / cache ────────────────────────────────────────────────────

local function decode(row)
    row.branding = row.branding and json.decode(row.branding) or {}
    row.register_coords = row.register_coords and json.decode(row.register_coords) or nil
    row.webhook_events = row.webhook_events and json.decode(row.webhook_events) or {}
    return row
end

function PStores.loadAll()
    cache, roster = {}, {}
    local rows = Db.query("SELECT * FROM sovereign_stores WHERE class = 'player'", {}) or {}
    for _, row in ipairs(rows) do
        cache[row.id] = decode(row)
        roster[row.id] = Db.query(
            'SELECT charid, permissions, pay_model, pay_rate, hired_at, hired_by FROM sovereign_store_employees WHERE store_id = ?',
            { row.id }) or {}
        Bridge.storage.register(row.id, row.name .. ' — Back Room', Config.StorageSlots)
    end
    local n = 0 for _ in pairs(cache) do n = n + 1 end
    republish()
    Util.ok(('player stores loaded: %d'):format(n))
    return n
end

function PStores.get(id) return cache[tonumber(id)] end
function PStores.all() return cache end
function PStores.staff(id) return roster[tonumber(id)] or {} end

-- ── Roles & permissions ─────────────────────────────────────────────

---@return 'owner'|'coowner'|'employee'|nil
function PStores.roleOf(id, charid)
    local s = cache[tonumber(id)]
    if not s or not charid then return nil end
    if s.owner_charid == charid then return 'owner' end
    if s.coowner_charid == charid then return 'coowner' end
    for _, e in ipairs(roster[s.id] or {}) do
        if e.charid == charid then return 'employee' end
    end
    return nil
end

---Does this character hold a permission flag at this store?
function PStores.can(id, charid, flag)
    local role = PStores.roleOf(id, charid)
    if role == 'owner' or role == 'coowner' then return true end
    if role ~= 'employee' then return false end
    for _, e in ipairs(roster[tonumber(id)] or {}) do
        if e.charid == charid then return Perms.has(e.permissions, flag) end
    end
    return false
end

-- Anyone on staff (any role) can clock in / use the staff panel.
function PStores.isStaff(id, charid)
    return PStores.roleOf(id, charid) ~= nil
end

-- ── Admin operations (Bureau, H3) — caller must pass Bridge.isAdmin ──

function PStores.create(data, actorCharid)
    local id = Db.insert(
        [[INSERT INTO sovereign_stores (class, name, category, status, register_coords, npc_model)
          VALUES ('player', ?, ?, 'closed', ?, ?)]],
        { data.name, data.category or 'general',
          data.coords and json.encode(data.coords) or nil, data.npcModel })
    if not id then return nil, 'db' end
    cache[id] = decode({
        id = id, class = 'player', name = data.name, category = data.category or 'general',
        status = 'closed', purchase_price = 0, tax_rate = 0, tax_state = 'current',
        branding = json.encode({}), register_coords = data.coords and json.encode(data.coords) or nil,
        npc_model = data.npcModel,
    })
    roster[id] = {}
    Bridge.storage.register(id, data.name .. ' — Back Room', Config.StorageSlots)
    EventLog.write(id, 'assigned', actorCharid, nil, { created = true, name = data.name })
    republish()
    return id
end

function PStores.setCode(id, code, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    code = tostring(code or ''):upper()
    if not code:match('^%u%u%u$') then return false, 'bad_code' end
    -- the table's unique constraint enforces global code uniqueness
    local done = Db.execute('UPDATE sovereign_stores SET code = ? WHERE id = ?', { code, s.id })
    if not done or done == 0 then return false, 'code_taken' end
    s.code = code
    EventLog.write(s.id, 'code_set', actorCharid, nil, { code = code })
    return true
end

function PStores.assignOwner(id, charid, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    Db.execute("UPDATE sovereign_stores SET owner_charid = ?, status = IF(status='repossessed','closed',status) WHERE id = ?", { charid, s.id })
    if s.status == 'repossessed' then s.status = 'closed' end
    s.owner_charid = charid
    EventLog.write(s.id, 'assigned', actorCharid, charid, {})
    return true
end

function PStores.setPurchasePrice(id, price, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    price = Util.round2(price)
    if price < 0 then return false, 'bad_price' end
    Db.execute('UPDATE sovereign_stores SET purchase_price = ? WHERE id = ?', { price, s.id })
    s.purchase_price = price
    EventLog.write(s.id, 'price_set', actorCharid, nil, { price = price })
    return true
end

function PStores.setTaxRate(id, rate, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    rate = tonumber(rate) or -1
    if rate < 0 or rate > 100 then return false, 'bad_rate' end
    Db.execute('UPDATE sovereign_stores SET tax_rate = ? WHERE id = ?', { rate, s.id })
    s.tax_rate = rate
    EventLog.write(s.id, 'tax_rate_set', actorCharid, nil, { rate = rate })
    return true
end

function PStores.transferOwner(id, newCharid, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    local old = s.owner_charid
    Db.execute('UPDATE sovereign_stores SET owner_charid = ?, coowner_charid = NULL WHERE id = ?', { newCharid, s.id })
    s.owner_charid, s.coowner_charid = newCharid, nil
    EventLog.write(s.id, 'transfer', actorCharid, newCharid, { from = old })
    return true
end

---Full teardown (design §5): strip roles, clear roster, sweep ledgers
---to the government fund, close. Used by tax/inactivity automation too.
function PStores.repossess(id, reason, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    local swept = Ledger.sweepToFund(s.id, reason or 'repossession')
    Db.execute('DELETE FROM sovereign_store_employees WHERE store_id = ?', { s.id })
    roster[s.id] = {}
    Db.execute([[UPDATE sovereign_stores SET owner_charid = NULL, coowner_charid = NULL,
                 status = 'repossessed', tax_state = 'current', delinquent_since = NULL WHERE id = ?]], { s.id })
    s.owner_charid, s.coowner_charid, s.status, s.tax_state = nil, nil, 'repossessed', 'current'
    EventLog.write(s.id, 'repossessed', actorCharid, nil, { reason = reason, swept = swept })
    TriggerEvent('sovereign_stores:repossessed', { store = s.id, reason = reason, swept = swept })
    republish()
    return true, swept
end

---Admin override for approved absences (H6). untilDate 'YYYY-MM-DD' or nil to clear.
function PStores.setInactivityExempt(id, untilDate, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    if untilDate and not tostring(untilDate):match('^%d%d%d%d%-%d%d%-%d%d$') then return false, 'bad_date' end
    Db.execute('UPDATE sovereign_stores SET inactivity_exempt_until = ? WHERE id = ?', { untilDate, s.id })
    s.inactivity_exempt_until = untilDate
    EventLog.write(s.id, 'adjustment', actorCharid, nil, { inactivity_exempt_until = untilDate })
    return true
end

-- ── Owner / co-owner operations (Management panel) ──────────────────

function PStores.setCoOwner(id, charid, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    if charid and s.coowner_charid then return false, 'coowner_cap' end
    local previous = s.coowner_charid
    Db.execute('UPDATE sovereign_stores SET coowner_charid = ? WHERE id = ?', { charid, s.id })
    s.coowner_charid = charid
    EventLog.write(s.id, charid and 'hired' or 'fired', actorCharid, charid or previous, { role = 'coowner' })
    return true
end

function PStores.hire(id, charid, permissions, payModel, payRate, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    if PStores.roleOf(id, charid) then return false, 'already_staff' end
    if #(roster[s.id] or {}) >= Config.MaxEmployees then return false, 'employee_cap' end
    if payModel ~= 'hourly' and payModel ~= 'daily' then payModel = 'hourly' end
    local perms = Perms.clean(permissions)
    local rate = math.max(0, Util.round2(payRate))
    local rowId = Db.insert(
        'INSERT INTO sovereign_store_employees (store_id, charid, permissions, pay_model, pay_rate, hired_by) VALUES (?, ?, ?, ?, ?, ?)',
        { s.id, charid, perms, payModel, rate, actorCharid })
    if not rowId then return false, 'db' end
    roster[s.id][#roster[s.id] + 1] = {
        charid = charid, permissions = perms, pay_model = payModel, pay_rate = rate, hired_by = actorCharid,
    }
    EventLog.write(s.id, 'hired', actorCharid, charid, { perms = perms, pay_model = payModel, rate = rate })
    return true
end

function PStores.fire(id, charid, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    if s.coowner_charid == charid then return PStores.setCoOwner(id, nil, actorCharid) end
    local list = roster[s.id] or {}
    for i, e in ipairs(list) do
        if e.charid == charid then
            Db.execute('DELETE FROM sovereign_store_employees WHERE store_id = ? AND charid = ?', { s.id, charid })
            table.remove(list, i)
            EventLog.write(s.id, 'fired', actorCharid, charid, {})
            return true
        end
    end
    return false, 'not_staff'
end

function PStores.setEmployee(id, charid, permissions, payModel, payRate, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    for _, e in ipairs(roster[s.id] or {}) do
        if e.charid == charid then
            e.permissions = Perms.clean(permissions)
            if payModel == 'hourly' or payModel == 'daily' then e.pay_model = payModel end
            if payRate ~= nil then e.pay_rate = math.max(0, Util.round2(payRate)) end
            Db.execute(
                'UPDATE sovereign_store_employees SET permissions = ?, pay_model = ?, pay_rate = ? WHERE store_id = ? AND charid = ?',
                { e.permissions, e.pay_model, e.pay_rate, s.id, charid })
            EventLog.write(s.id, 'perms_changed', actorCharid, charid,
                { perms = e.permissions, pay_model = e.pay_model, rate = e.pay_rate })
            return true
        end
    end
    return false, 'not_staff'
end

function PStores.setStatus(id, open, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    if s.status == 'repossessed' then return false, 'repossessed' end
    local status = open and 'open' or 'closed'
    Db.execute('UPDATE sovereign_stores SET status = ? WHERE id = ?', { status, s.id })
    s.status = status
    EventLog.write(s.id, open and 'open' or 'close', actorCharid, nil, {})
    TriggerEvent(open and 'sovereign_stores:storeOpened' or 'sovereign_stores:storeClosed', { store = s.id })
    republish()
    return true
end

function PStores.setBranding(id, branding, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    -- curated fields only (design §8.5) — no arbitrary keys
    local clean = {
        tagline        = branding.tagline and tostring(branding.tagline):sub(1, 80) or nil,
        accent         = branding.accent and tostring(branding.accent):sub(1, 24) or nil,
        motif          = branding.motif and tostring(branding.motif):sub(1, 24) or nil,
        closed_message = branding.closed_message and tostring(branding.closed_message):sub(1, 160) or nil,
    }
    Db.execute('UPDATE sovereign_stores SET branding = ? WHERE id = ?', { json.encode(clean), s.id })
    s.branding = clean
    EventLog.write(s.id, 'branding', actorCharid, nil, clean)
    return true
end

function PStores.rename(id, name, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    name = tostring(name or ''):sub(1, 48)
    if #name < 3 then return false, 'bad_name' end
    Db.execute('UPDATE sovereign_stores SET name = ? WHERE id = ?', { name, s.id })
    s.name = name
    EventLog.write(s.id, 'branding', actorCharid, nil, { name = name })
    republish()
    return true
end

-- ── Funds (Management panel; permission-gated) ──────────────────────

---Deposit cash into a ledger. account 'operating' or 'tax'.
function PStores.deposit(id, src, account, amount)
    local s = cache[tonumber(id)]
    local charid = Bridge.getCharId(src)
    if not s or not charid then return false, 'unknown' end
    if not PStores.can(id, charid, Perms.FUNDS_DEPOSIT) then return false, 'no_permission' end
    if account ~= 'operating' and account ~= 'tax' then return false, 'bad_account' end
    amount = Util.round2(amount)
    if amount <= 0 then return false, 'bad_amount' end
    if not Bridge.money.remove(src, amount) then return false, 'cant_afford' end
    Ledger.write(s.id, account, 'deposit', amount, { actor = charid })
    return true, Ledger.balance(s.id, account)
end

---Withdraw cash from the OPERATING ledger only (tax is deposit-only, §4.2).
function PStores.withdraw(id, src, amount)
    local s = cache[tonumber(id)]
    local charid = Bridge.getCharId(src)
    if not s or not charid then return false, 'unknown' end
    if not PStores.can(id, charid, Perms.FUNDS_WITHDRAW) then return false, 'no_permission' end
    amount = Util.round2(amount)
    if amount <= 0 then return false, 'bad_amount' end
    local ok = Ledger.write(s.id, 'operating', 'withdrawal', -amount, { actor = charid })
    if not ok then return false, 'insufficient' end
    Bridge.money.add(src, amount)
    return true, Ledger.balance(s.id, 'operating')
end
