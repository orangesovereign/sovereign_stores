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
    for _, s in pairs(PStores.all()) do
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

Boot.integration = true
