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

---A store is one person's business (owner ruling 2026-08-09). When it
---ends — sold back, seized, revoked — it RETIRES: the record survives
---for the history and for weapon-serial provenance, but it leaves the
---working directory so someone else can charter their own store on the
---same premises. 'repossessed' is the legacy spelling of the same idea
---and counts as retired everywhere.
function PStores.isRetired(s)
    if type(s) ~= 'table' then s = cache[tonumber(s)] end
    if not s then return false end
    return s.status == 'archived' or s.status == 'repossessed'
end

---Every store that is still a going concern.
function PStores.active()
    local out = {}
    for id, s in pairs(cache) do
        if not PStores.isRetired(s) then out[id] = s end
    end
    return out
end

---Re-read one store from the database into the cache. The Phase 4
---schedulers write tax/status columns in SQL (so the arithmetic happens
---where the dates live); this pulls the result back into memory.
function PStores.refresh(id)
    id = tonumber(id)
    local rows = Db.query('SELECT * FROM sovereign_stores WHERE id = ? LIMIT 1', { id })
    local row = rows and rows[1]
    if not row then return nil end
    cache[id] = decode(row)
    return cache[id]
end
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
    -- Retired is terminal (one-off rule): a finished business is never
    -- handed to someone new — they charter their own on the premises.
    if PStores.isRetired(s) then return false, 'retired' end
    Db.execute("UPDATE sovereign_stores SET owner_charid = ? WHERE id = ?", { charid, s.id })
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
---Retire a store for good. Shared ending for every path: the roster is
---dissolved, the doors close, the tax clock stops, and it drops out of
---the working directory. The row itself is KEPT — weapon serials point
---at it, and the county's history should not evaporate.
---Callers handle the money first (sweep or pay out) — this only ends it.
---@param archiveReason string  sold_back | tax | inactivity | admin
function PStores.archive(id, archiveReason, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    if PStores.isRetired(s) then return true end   -- already ended; nothing to undo

    Db.execute('DELETE FROM sovereign_store_employees WHERE store_id = ?', { s.id })
    roster[s.id] = {}
    Db.execute([[UPDATE sovereign_stores SET owner_charid = NULL, coowner_charid = NULL,
                 status = 'archived', archived_at = NOW(), archive_reason = ?,
                 tax_state = 'current', delinquent_since = NULL, tax_due_date = NULL
                 WHERE id = ?]], { archiveReason or 'admin', s.id })
    s.owner_charid, s.coowner_charid = nil, nil
    s.status, s.archive_reason = 'archived', archiveReason or 'admin'
    s.tax_state, s.delinquent_since, s.tax_due_date = 'current', nil, nil

    EventLog.write(s.id, 'archived', actorCharid, nil, { reason = archiveReason })
    TriggerEvent('sovereign_stores:archived',
        { store = s.id, code = s.code, name = s.name, reason = archiveReason })
    republish()
    return true
end

function PStores.repossess(id, reason, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    if PStores.isRetired(s) then return false, 'already_retired' end
    local swept = Ledger.sweepToFund(s.id, reason or 'repossession')
    local former = s.owner_charid
    -- A seizure ends the business like any other ending (one-off rule):
    -- the county does not keep a going concern on the books for reassignment.
    PStores.archive(s.id, (reason and reason:find('absent')) and 'inactivity' or 'tax', actorCharid)
    EventLog.write(s.id, 'repossessed', actorCharid, former, { reason = reason, swept = swept })
    TriggerEvent('sovereign_stores:repossessed', { store = s.id, reason = reason, swept = swept })
    return true, swept
end

---Vacate a store the owner is GIVING UP — a voluntary sale-back, not a
---seizure. Contrast PStores.repossess, which sweeps both ledgers into the
---treasury; here the departing owner keeps what they earned (owner ruling
---2026-08-09).
---
---Order matters, and it is the fair one:
---  1. anyone still on the clock is punched out, so wages settle from the
---     operating ledger BEFORE the owner cashes out
---  2. the county collects tax it is already owed — selling must not be a
---     way to walk away from an assessment
---  3. whatever remains in BOTH ledgers is paid to the departing owner
---  4. the business RETIRES to the archive — a store belongs to one
---     person, not to the building — so the premises stand free for
---     someone else to charter their own
---
---If the owner is offline we cannot put cash in their hand, so the money
---is LEFT in the ledgers rather than vaporised — visible and recoverable.
---@return boolean ok, number|string payout, number settled
function PStores.release(id, opts)
    opts = opts or {}
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown', 0 end

    local owner = tonumber(opts.toCharid) or s.owner_charid
    local reason = opts.reason or 'sold back'

    -- 1) settle wages first
    if Shifts and Shifts.roster then
        for _, sh in ipairs(Shifts.roster(s.id)) do
            Shifts.clockOut(sh.charid, 'store_sold')
        end
    end

    local operating = Ledger.balance(s.id, 'operating')
    local reserve   = Ledger.balance(s.id, 'tax')

    -- 2) the county's claim, if any
    local settled = 0
    if s.tax_state == 'delinquent' and Taxes and Taxes.quote then
        local owed = tonumber((Taxes.quote(s) or {}).amount) or 0
        settled = math.min(owed, Util.round2(operating + reserve))
        if settled > 0 then
            local fromReserve = math.min(reserve, settled)
            if fromReserve > 0 then
                Ledger.write(s.id, 'tax', 'tax_collected', -fromReserve, { note = 'settled on sale' })
                reserve = Util.round2(reserve - fromReserve)
            end
            local fromOperating = Util.round2(settled - fromReserve)
            if fromOperating > 0 then
                Ledger.write(s.id, 'operating', 'tax_collected', -fromOperating, { note = 'settled on sale' })
                operating = Util.round2(operating - fromOperating)
            end
            Fund.credit('tax', settled, s.id, ('settled on sale of %s'):format(s.name))
        end
    end

    -- 3) pay the departing owner out
    local payout = Util.round2(operating + reserve)
    local src = owner and Bridge.srcByCharId(owner) or nil
    if payout > 0 and src then
        if operating > 0 then
            Ledger.write(s.id, 'operating', 'withdrawal', -operating,
                { actor = owner, note = 'paid out on ' .. reason })
        end
        if reserve > 0 then
            Ledger.write(s.id, 'tax', 'withdrawal', -reserve,
                { actor = owner, note = 'paid out on ' .. reason })
        end
        Bridge.money.add(src, payout)
        Bridge.notify(src, _U('store_released_paid', payout))
    elseif payout > 0 then
        Util.warn(('release: %s holds $%.2f but its owner is offline — left in the ledgers'):format(
            s.name, payout))
        payout = 0
    end

    -- 4) the business ends here (one-off rule) — archive frees the premises
    PStores.archive(s.id, 'sold_back', opts.actorCharid)

    EventLog.write(s.id, 'released', opts.actorCharid, owner,
        { reason = reason, payout = payout, settled = settled })
    TriggerEvent('sovereign_stores:released',
        { store = s.id, code = s.code, name = s.name, formerOwner = owner,
          reason = reason, payout = payout, settled = settled })
    republish()
    return true, payout, settled
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
    if charid then
        -- promotion consumes the old post — one person, one role (duo D10:
        -- a lingering employee row doubled permissions and ate a staff slot)
        Db.execute('DELETE FROM sovereign_store_employees WHERE store_id = ? AND charid = ?', { s.id, charid })
        local list = roster[s.id] or {}
        for i = #list, 1, -1 do
            if list[i].charid == charid then table.remove(list, i) end
        end
    end
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
    if PStores.isRetired(s) then return false, 'retired' end
    local status = open and 'open' or 'closed'
    Db.execute('UPDATE sovereign_stores SET status = ? WHERE id = ?', { status, s.id })
    s.status = status
    EventLog.write(s.id, open and 'open' or 'close', actorCharid, nil, {})
    TriggerEvent(open and 'sovereign_stores:storeOpened' or 'sovereign_stores:storeClosed',
        { store = s.id, name = s.name, code = s.code })
    if Webhooks then
        Webhooks.fire(s.id, 'storefront', {
            title = open and _U('wh_opened') or _U('wh_closed'),
            color = open and 0x7D8D5C or 0x6A5D4C,
            fields = { { name = _U('wh_store'), value = s.name } },
        })
    end
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

---Blip options for a store: its category's list plus the universal set.
function PStores.blipOptions(category)
    local out = {}
    for _, o in ipairs((Config.BlipCatalog.categories or {})[category] or {}) do out[#out + 1] = o end
    for _, o in ipairs(Config.BlipCatalog.universal or {}) do out[#out + 1] = o end
    return out
end

---Resolve a store's chosen blip (or its category default) to sprite+color.
function PStores.blipOf(s)
    local options = PStores.blipOptions(s.category)
    local chosen = s.branding and s.branding.blip_key
    for _, o in ipairs(options) do
        if o.key == chosen then return o end
    end
    return options[1] or { sprite = 'blip_shop_store' }
end

---Owner-selectable map blip, validated against the curated catalog.
function PStores.setBlip(id, key, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    local valid = false
    for _, o in ipairs(PStores.blipOptions(s.category)) do
        if o.key == key then valid = true break end
    end
    if not valid then return false, 'bad_blip' end
    s.branding = s.branding or {}
    s.branding.blip_key = key
    Db.execute('UPDATE sovereign_stores SET branding = ? WHERE id = ?', { json.encode(s.branding), s.id })
    EventLog.write(s.id, 'blip_set', actorCharid, nil, { key = key })
    republish()
    return true
end

---Owner-selectable cashier, validated against the curated config list.
function PStores.setCashier(id, model, actorCharid)
    local s = cache[tonumber(id)]
    if not s then return false, 'unknown' end
    model = tostring(model or ''):lower()
    local valid = false
    for _, group in ipairs(Config.CashierPeds or {}) do
        for _, ped in ipairs(group.peds) do
            if ped.model:lower() == model then valid = true break end
        end
        if valid then break end
    end
    if not valid then return false, 'bad_model' end
    Db.execute('UPDATE sovereign_stores SET npc_model = ? WHERE id = ?', { model, s.id })
    s.npc_model = model
    EventLog.write(s.id, 'cashier_set', actorCharid, nil, { model = model })
    republish()
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

Boot.player_stores = true
