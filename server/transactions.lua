--[[=====================================================================
  SOVEREIGN STORES · TRANSACTION ENGINE v1 (features C2/C3/C7/C8, B7-B9)
  Server-authoritative: prices come from the validated runtime catalog,
  never the client; proximity and job gates re-checked here; carts are
  all-or-nothing. Cash only (owner decision).

  Degradable sells are per-stack: the client offers a stack (qty +
  condition% as the server reported it); we re-verify a matching stack
  exists before paying. Condition may tick down between report and sale,
  so matching allows a small tolerance and payout uses the LIVE value.
=====================================================================]]--

local Core = nil
CreateThread(function() Core = Bridge.core() end)

local MAX_LINE_QTY <const> = 99
local PCT_TOLERANCE <const> = 3   -- decay ticks between browse and sell

local function findBuyEntry(store, item)
    for _, e in ipairs(store.buy) do if e.item == item then return e end end
    return nil
end

-- One price authority for buys: sale-aware, mirrored exactly by the UI.
local function unitPrice(entry)
    if entry.salePercent and entry.salePercent > 0 then
        return Util.round2(entry.price * (1 - entry.salePercent / 100))
    end
    return entry.price
end

local function findSellEntry(store, item)
    for _, e in ipairs(store.sell) do if e.item == item then return e end end
    return nil
end

-- ── Browse: catalog + the player's sellable goods ───────────────────

local function buildSellView(src, store)
    local view = {}
    if #store.sell == 0 then return view end

    local inv = Bridge.inv.getAll(src)
    local weapons = nil

    for _, entry in ipairs(store.sell) do
        local stacks = {}
        if entry.weapon then
            weapons = weapons or Bridge.weapons.getAll(src)
            local count = 0
            for _, w in pairs(weapons) do
                if w.name == entry.item and not w.used and not w.used2 then count = count + 1 end
            end
            if count > 0 then stacks[#stacks + 1] = { qty = count, weapon = true } end
        else
            for _, st in pairs(inv) do
                if st.name == entry.item then
                    local pct = tonumber(st.percentage) or 0
                    local degradable = st.isDegradable == true
                    local eligible = true
                    if degradable and entry.minCondition and pct < entry.minCondition then eligible = false end
                    if eligible then
                        stacks[#stacks + 1] = {
                            qty = st.count or 0,
                            percentage = degradable and pct or nil,
                            metadata = st.metadata or {},
                        }
                    end
                end
            end
        end
        -- ALWAYS list the entry — the buy-board shows what the clerk buys even
        -- when the player carries none (ledger Phase 1 C1 confusion fix)
        view[#view + 1] = {
            item = entry.item, label = entry.label, price = entry.price,
            category = entry.category, weapon = entry.weapon,
            minCondition = entry.minCondition, scaleByCondition = entry.scaleByCondition,
            stacks = stacks,
        }
    end
    return view
end

local function storePayload(src, store)
    return {
        ok = true,
        store = {
            key = store.key, label = store.label, category = store.category,
            est = store.est, tagline = store.tagline, notice = store.notice,
            code = store.code, playerStore = store.playerStore,
            closed = store.closed or false, closedMessage = store.closedMessage,
            categories = store.categories,
            buy = store.closed and {} or store.buy,
            sell = store.closed and {} or buildSellView(src, store),
        },
        money = Bridge.money.get(src),
    }
end

-- ── Player-store resolution ─────────────────────────────────────────
-- Player stores trade under the key 'p:<id>' through the same engine.

local function playerStoreNear(src, s)
    local rc = s.register_coords
    if not rc then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local maxD = Config.ServerTradeDistance or 12.0
    local dx, dy, dz = p.x - rc.x, p.y - rc.y, p.z - rc.z
    return (dx * dx + dy * dy + dz * dz) <= (maxD * maxD)
end

local function playerStoreView(s)
    local catalog = Stock.catalog(s.id)
    local cats, seen = {}, {}
    for _, e in ipairs(catalog) do
        if not seen[e.category] then
            seen[e.category] = true
            cats[#cats + 1] = { key = e.category, label = (e.category:gsub('^%l', string.upper)) }
        end
    end
    return {
        key = 'p:' .. s.id, id = s.id, playerStore = true,
        label = s.name, code = s.code, category = s.category,
        tagline = s.branding and s.branding.tagline or nil,
        est = 'SOVEREIGN COUNTY CHARTER' .. (s.code and (' · ' .. s.code) or ''),
        categories = #cats > 0 and cats or { { key = 'general', label = 'Goods' } },
        buy = catalog,
        sell = {},   -- buy orders arrive in Phase 4
        closed = s.status ~= 'open',
        closedMessage = (s.branding and s.branding.closed_message) or nil,
    }
end

-- ── Guards ──────────────────────────────────────────────────────────

local function guard(src, storeKey)
    local pid = tostring(storeKey):match('^p:(%d+)$')
    if pid then
        local s = PStores.get(tonumber(pid))
        if not s or s.status == 'repossessed' then return nil, 'unknown_store' end
        if not playerStoreNear(src, s) then return nil, 'too_far' end
        return playerStoreView(s), nil, s
    end
    local store = Npc.get(storeKey)
    if not store then return nil, 'unknown_store' end
    if not Npc.playerNear(src, storeKey) then return nil, 'too_far' end
    if not Npc.jobAllowed(src, storeKey) then return nil, 'job_locked' end
    return store
end

-- ── Checkout (buy) — all-or-nothing ─────────────────────────────────

local function checkout(src, storeKey, cart)
    local store, err, pstore = guard(src, storeKey)
    if not store then return { ok = false, error = err } end
    if store.closed then return { ok = false, error = 'closed' } end
    if type(cart) ~= 'table' or #cart == 0 then return { ok = false, error = 'empty_cart' } end

    -- resolve + price every line server-side
    local lines, total = {}, 0
    for _, raw in ipairs(cart) do
        local qty = math.floor(tonumber(raw.qty) or 0)
        local entry = findBuyEntry(store, tostring(raw.item))
        if not entry or qty < 1 or qty > MAX_LINE_QTY then
            return { ok = false, error = 'bad_line' }
        end
        if pstore and (entry.stock or 0) < qty then
            return { ok = false, error = 'out_of_stock', item = entry.label }
        end
        local unit = unitPrice(entry)
        lines[#lines + 1] = { entry = entry, qty = qty, cost = Util.round2(unit * qty) }
        total = Util.round2(total + unit * qty)
    end

    if not Bridge.money.canAfford(src, total) then
        return { ok = false, error = 'cant_afford', money = Bridge.money.get(src) }
    end

    -- carry checks before any money moves
    for _, line in ipairs(lines) do
        local fits = line.entry.weapon
            and Bridge.weapons.canCarry(src, line.qty, line.entry.item)
            or Bridge.inv.canCarry(src, line.entry.item, line.qty)
        if not fits then
            return { ok = false, error = 'cant_carry', item = line.entry.label }
        end
    end

    if not Bridge.money.remove(src, total) then
        return { ok = false, error = 'cant_afford', money = Bridge.money.get(src) }
    end

    -- deliver; refund any line that fails (post-canCarry failures are rare)
    local delivered = 0
    for _, line in ipairs(lines) do
        local okLine = true
        if pstore then
            -- shelf is authoritative: claim stock BEFORE handing goods over
            if not Stock.take(pstore.id, line.entry.item, line.qty) then okLine = false end
        end
        if okLine then
            if line.entry.weapon then
                for _ = 1, line.qty do
                    if not Bridge.weapons.createStamped(src, line.entry.item, nil, nil, nil) then okLine = false end
                end
            else
                okLine = Bridge.inv.add(src, line.entry.item, line.qty)
            end
        end
        if okLine then
            delivered = Util.round2(delivered + line.cost)
        else
            Bridge.money.add(src, line.cost)
            Util.err(('checkout: delivery failed for %s x%d (player %s) — refunded %.2f'):format(
                line.entry.item, line.qty, src, line.cost))
        end
    end

    if delivered > 0 then
        if pstore then
            Ledger.write(pstore.id, 'operating', 'sale', delivered, {
                actor = Bridge.getCharId(src), note = ('%d line(s)'):format(#lines),
            })
        else
            Fund.credit('npc_sale', delivered, nil, store.key)
        end
        TriggerEvent('sovereign_stores:itemPurchased', { src = src, store = store.key, total = delivered })
        Bridge.notify(src, _U('bought_total', delivered))
    end

    return { ok = delivered > 0, total = delivered, money = Bridge.money.get(src) }
end

-- ── Sell to store ───────────────────────────────────────────────────

local function sellStack(src, store, req)
    local entry = findSellEntry(store, tostring(req.item))
    local qty = math.floor(tonumber(req.qty) or 0)
    if not entry or qty < 1 or qty > MAX_LINE_QTY then return nil, 'bad_line' end

    if entry.weapon then
        local removed = 0
        for _, w in pairs(Bridge.weapons.getAll(src)) do
            if removed >= qty then break end
            if w.name == entry.item and not w.used and not w.used2 then
                if Bridge.weapons.delete(src, w.id) then removed = removed + 1 end
            end
        end
        if removed == 0 then return nil, 'not_owned' end
        return Util.round2(entry.price * removed), nil, removed
    end

    -- re-verify a live matching stack (condition may have ticked down)
    local live = nil
    for _, st in pairs(Bridge.inv.getAll(src)) do
        if st.name == entry.item and (st.count or 0) >= qty then
            local pct = tonumber(st.percentage) or 0
            if req.percentage == nil then
                if not st.isDegradable then live = st break end
            elseif st.isDegradable and math.abs(pct - (tonumber(req.percentage) or 0)) <= PCT_TOLERANCE then
                live = st break
            end
        end
    end
    if not live then return nil, 'stack_gone' end

    local pct = tonumber(live.percentage) or 100
    if live.isDegradable and entry.minCondition and pct < entry.minCondition then
        return nil, 'too_worn'
    end

    if not Bridge.inv.sub(src, entry.item, qty, next(live.metadata or {}) and live.metadata or nil) then
        return nil, 'sub_failed'
    end

    local unit = entry.price
    if live.isDegradable and entry.scaleByCondition then
        unit = entry.price * (pct / 100)
    end
    return Util.round2(unit * qty), nil, qty
end

local function sellToStore(src, storeKey, entries)
    local store, err = guard(src, storeKey)
    if not store then return { ok = false, error = err } end
    if store.closed or store.playerStore then return { ok = false, error = 'closed' } end
    if type(entries) ~= 'table' or #entries == 0 then return { ok = false, error = 'empty' } end

    local total, sold = 0, 0
    for _, req in ipairs(entries) do
        local amount, sellErr = sellStack(src, store, req)
        if amount then
            total = Util.round2(total + amount)
            sold = sold + 1
        else
            Util.debug(('sell refused (%s): %s'):format(tostring(req.item), tostring(sellErr)))
        end
    end

    if total > 0 then
        Bridge.money.add(src, total)
        Fund.debit('npc_purchase', total, nil, store.key)
        TriggerEvent('sovereign_stores:itemSold', { src = src, store = store.key, total = total })
        Bridge.notify(src, _U('sold_total', total))
    end

    return { ok = sold > 0, total = total, money = Bridge.money.get(src) }
end

-- ── Callbacks ───────────────────────────────────────────────────────

CreateThread(function()
    while not Bridge.core() do Wait(250) end
    local C = Bridge.core()

    C.Callback.Register('sovereign_stores:getStore', function(source, cb, storeKey)
        local store, err = guard(source, tostring(storeKey))
        if not store then return cb({ ok = false, error = err }) end
        cb(storePayload(source, store))
    end)

    C.Callback.Register('sovereign_stores:checkout', function(source, cb, storeKey, cart)
        cb(checkout(source, tostring(storeKey), cart))
    end)

    C.Callback.Register('sovereign_stores:sell', function(source, cb, storeKey, entries)
        cb(sellToStore(source, tostring(storeKey), entries))
    end)
end)
