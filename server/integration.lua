--[[=====================================================================
  SOVEREIGN STORES · INTEGRATION SURFACE (feature I3)

  What other county scripts may ask of us, and what we announce to them.
  Versioned from day one: additions are safe, removals are not.

  EXPORTS (server)
    GetStoreByCode(code)              -> store summary | nil
    GetStoreInfo(storeId)             -> store summary | nil
    ListStores(opts)                  -> array of summaries
    IsStoreStaff(charid, storeId)     -> role string | nil
    GetStoresForCharacter(charid)     -> array of { id, role }
    AssignOwner(storeId, charid)      -> ok, err     (realty script hook)
    ReleaseStore(storeId, opts)       -> ok, payout, settled  (realty sale-back)
    ArchiveStore(storeId, reason)     -> ok, err     (retire without touching money)
    CreateStore(data)                 -> storeId, err (county-script charter hook)
    LookupWeaponSerial(serial)        -> registry row (server/serials.lua)
    GetGovernmentFund()               -> number      (server/fund.lua)
    SpendGovernmentFund(amount, note) -> ok          (server/fund.lua)

  EVENTS (server-side TriggerEvent, listen with AddEventHandler)
    sovereign_stores:itemPurchased  { src, store, total }
    sovereign_stores:itemSold       { src, store, item, qty, total }
    sovereign_stores:storeOpened    { store, name, code }
    sovereign_stores:storeClosed    { store, name, code }
    sovereign_stores:employeeClockIn{ store, charid }
    sovereign_stores:repossessed    { store, reason, swept }
    sovereign_stores:released       { store, code, name, formerOwner, reason, payout, settled }
    sovereign_stores:archived       { store, code, name, reason }
=====================================================================]]--

local function summarize(s)
    if not s then return nil end
    return {
        id = s.id, code = s.code, name = s.name, category = s.category,
        status = s.status, class = s.class or 'player',
        ownerCharid = s.owner_charid, coownerCharid = s.coowner_charid,
        taxState = s.tax_state, taxDue = s.tax_due_date,
        coords = s.register_coords,
        balances = { operating = Ledger.balance(s.id, 'operating'), tax = Ledger.balance(s.id, 'tax') },
    }
end

exports('GetStoreInfo', function(storeId)
    return summarize(PStores.get(tonumber(storeId)))
end)

exports('GetStoreByCode', function(code)
    code = tostring(code or ''):upper()
    for _, s in pairs(PStores.all()) do
        if s.code and s.code:upper() == code then return summarize(s) end
    end
    return nil
end)

exports('ListStores', function(opts)
    opts = opts or {}
    local out = {}
    -- going concerns only unless the caller explicitly wants the archive
    for _, s in pairs(opts.includeRetired and PStores.all() or PStores.active()) do
        local keep = true
        if opts.status and s.status ~= opts.status then keep = false end
        if opts.category and s.category ~= opts.category then keep = false end
        if opts.ownedOnly and not s.owner_charid then keep = false end
        if keep then out[#out + 1] = summarize(s) end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end)

exports('IsStoreStaff', function(charid, storeId)
    return PStores.roleOf(tonumber(storeId), tonumber(charid))
end)

exports('GetStoresForCharacter', function(charid)
    charid = tonumber(charid)
    local out = {}
    for id, s in pairs(PStores.all()) do
        local role = PStores.roleOf(id, charid)
        if role then out[#out + 1] = { id = id, code = s.code, name = s.name, role = role, status = s.status } end
    end
    return out
end)

---For a future realty/auction script: hand a chartered store to a new owner.
---Starts the tax clock, exactly as the Bureau would.
exports('AssignOwner', function(storeId, charid)
    local ok, err = PStores.assignOwner(tonumber(storeId), tonumber(charid), nil)
    if ok then Taxes.startCycle(tonumber(storeId)) end
    return ok, err
end)

---The other half of AssignOwner, for when a realty sale hands the deed
---BACK rather than on: vacates the store without confiscating it. Wages
---settle first, the county collects any tax already owed, and whatever
---remains in both ledgers is paid to the departing owner (owner ruling
---2026-08-09). The business then RETIRES to the archive — a store is one
---person's, not a fixture — leaving the premises free for someone else's
---charter. Use PStores.repossess — not this — for a seizure.
---  opts = { toCharid?, reason?, actorCharid? }
--- returns ok, payout, settled
exports('ReleaseStore', function(storeId, opts)
    return PStores.release(tonumber(storeId), opts)
end)

---Retire a store outright, without moving any money. For a realty sale
---use ReleaseStore (it settles wages and pays the owner out first); this
---is the blunt instrument for a premises that is simply going away.
exports('ArchiveStore', function(storeId, reason)
    return PStores.archive(tonumber(storeId), reason or 'admin', nil)
end)

---For county scripts (e.g. sovereign_stables) that charter a storefront at their
---OWN location — a stable's store counter. Creates a player store, optionally
---assigns an owner and opens it. IDEMPOTENT when `code` is supplied: if a store
---with that 3-letter code already exists, its id is returned rather than a
---duplicate, so the caller can invoke this on every boot safely.
---  data = {
---    name,                 -- required; the shop name
---    coords = {x,y,z,h},   -- required; where the register + ped + prompts appear
---    category = 'general', -- optional
---    npcModel,             -- optional store-clerk model (its OWN ped)
---    code,                 -- optional 3 uppercase letters; enables idempotency + lookup
---    owner,                -- optional charid to assign (starts the tax clock)
---    open,                 -- optional bool; open the store immediately
---  }
--- returns storeId, err
exports('CreateStore', function(data)
    if type(data) ~= 'table' or not data.name or not data.coords then return nil, 'bad_data' end

    local code = data.code and tostring(data.code):upper() or nil
    if code and not code:match('^%u%u%u$') then return nil, 'bad_code' end

    -- Idempotency: reuse a LIVE store carrying the same code. A retired
    -- one is never resurrected (one-off rule) — but its code stays
    -- reserved forever, because weapon serials still point at it, so a
    -- fresh charter here will simply carry no code until an admin stamps
    -- a new one.
    if code then
        for _, s in pairs(PStores.active()) do
            if s.code and s.code:upper() == code then return s.id end
        end
    end

    local id, err = PStores.create({
        name = data.name, category = data.category or 'general',
        coords = data.coords, npcModel = data.npcModel,
    }, nil)
    if not id then return nil, err or 'db' end

    if code then PStores.setCode(id, code, nil) end
    if data.owner then
        local ok = PStores.assignOwner(id, tonumber(data.owner), nil)
        if ok then Taxes.startCycle(id) end
    end
    if data.open then PStores.setStatus(id, true, nil) end
    return id
end)

Boot.integration = true
