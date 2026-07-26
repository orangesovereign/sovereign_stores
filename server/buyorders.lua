--[[=====================================================================
  SOVEREIGN STORES · BUY ORDERS (feature D5)

  A store can stand on the other side of the counter: "I'll pay $2 a
  pelt, I want forty." Players sell into it through the same Sell tab
  the NPC stores use — the storefront doesn't care which kind of buyer
  is behind the counter.

  Money moves from the store's OPERATING ledger to the seller; goods go
  into the store's back room. When the ledger can no longer cover the
  next unit, the order AUTO-PAUSES rather than promising money the store
  doesn't have (design §5).
=====================================================================]]--

BuyOrders = {}

function BuyOrders.list(storeId)
    return Db.query(
        [[SELECT id, item, unit_price, qty_wanted, qty_filled, active, created_at
          FROM sovereign_store_buy_orders WHERE store_id = ? ORDER BY active DESC, id DESC]],
        { storeId }) or {}
end

---Orders a seller can actually fill right now: active, unfilled, funded.
function BuyOrders.open(storeId)
    local rows = Db.query(
        [[SELECT id, item, unit_price, qty_wanted, qty_filled FROM sovereign_store_buy_orders
          WHERE store_id = ? AND active = 1 AND qty_filled < qty_wanted ORDER BY id]],
        { storeId }) or {}
    local funds = Ledger.balance(storeId, 'operating')
    local out = {}
    for _, r in ipairs(rows) do
        local remaining = r.qty_wanted - r.qty_filled
        local affordable = math.floor(funds / math.max(0.01, tonumber(r.unit_price)))
        if affordable > 0 then
            out[#out + 1] = {
                id = r.id, item = r.item,
                price = Util.round2(r.unit_price),
                wanted = math.min(remaining, affordable),
                remaining = remaining,
            }
        end
    end
    return out
end

function BuyOrders.create(storeId, item, price, qty, actorCharid)
    item = tostring(item or '')
    price = Util.round2(tonumber(price) or -1)
    qty = math.floor(tonumber(qty) or 0)
    local maxQty = (Config.BuyOrders and Config.BuyOrders.MaxQtyEach) or 999
    if item == '' or price <= 0 or qty < 1 or qty > maxQty then return false, 'bad_input' end
    if item:find('^WEAPON_') then return false, 'no_weapon_orders' end

    local def = Bridge.inv.getDef(item)
    if not def then return false, 'unknown_item' end

    local count = tonumber(Db.scalar('SELECT COUNT(*) FROM sovereign_store_buy_orders WHERE store_id = ? AND active = 1', { storeId })) or 0
    if count >= ((Config.BuyOrders and Config.BuyOrders.MaxPerStore) or 12) then return false, 'order_cap' end

    Db.insert(
        'INSERT INTO sovereign_store_buy_orders (store_id, item, unit_price, qty_wanted) VALUES (?, ?, ?, ?)',
        { storeId, item, price, qty })
    EventLog.write(storeId, 'buy_order', actorCharid, nil, { item = item, price = price, qty = qty })
    return true
end

function BuyOrders.setActive(storeId, orderId, active, actorCharid)
    local n = Db.execute('UPDATE sovereign_store_buy_orders SET active = ? WHERE id = ? AND store_id = ?',
        { active and 1 or 0, orderId, storeId })
    if (n or 0) == 0 then return false, 'unknown_order' end
    EventLog.write(storeId, 'buy_order', actorCharid, nil, { order = orderId, active = active == true })
    return true
end

function BuyOrders.remove(storeId, orderId, actorCharid)
    local n = Db.execute('DELETE FROM sovereign_store_buy_orders WHERE id = ? AND store_id = ?', { orderId, storeId })
    if (n or 0) == 0 then return false, 'unknown_order' end
    EventLog.write(storeId, 'buy_order', actorCharid, nil, { order = orderId, removed = true })
    return true
end

---Fill an order from a player's satchel. Server-authoritative: price and
---remaining quantity come from the database, never the client.
---@return number|nil paid, string|nil err
function BuyOrders.fill(src, storeId, orderId, qty)
    qty = math.floor(tonumber(qty) or 0)
    if qty < 1 then return nil, 'bad_line' end

    local rows = Db.query(
        [[SELECT id, item, unit_price, qty_wanted, qty_filled, active FROM sovereign_store_buy_orders
          WHERE id = ? AND store_id = ? LIMIT 1]], { orderId, storeId })
    local o = rows and rows[1]
    if not o then return nil, 'unknown_order' end
    if o.active ~= 1 then return nil, 'order_paused' end

    local remaining = o.qty_wanted - o.qty_filled
    if remaining < 1 then return nil, 'order_filled' end
    if qty > remaining then qty = remaining end

    local unit = Util.round2(o.unit_price)
    local total = Util.round2(unit * qty)

    -- the store must be able to pay before a single item moves
    if Ledger.balance(storeId, 'operating') < total then
        BuyOrders.setActive(storeId, o.id, false, nil)
        return nil, 'store_broke'
    end

    local charid = Bridge.getCharId(src)
    if Bridge.inv.count(src, o.item) < qty then return nil, 'not_carried' end
    if not Bridge.inv.sub(src, o.item, qty) then return nil, 'sub_failed' end

    if not Bridge.storage.addItems(storeId, { { name = o.item, amount = qty } }, charid) then
        Bridge.inv.add(src, o.item, qty)      -- never eat goods
        return nil, 'storage_full'
    end

    local paidOk = Ledger.write(storeId, 'operating', 'purchase', -total, {
        actor = charid, item = o.item, qty = qty, note = ('buy order #%d'):format(o.id),
    })
    if not paidOk then
        -- ledger moved under us: put everything back exactly as it was
        Bridge.storage.removeItem(storeId, o.item, qty)
        Bridge.inv.add(src, o.item, qty)
        BuyOrders.setActive(storeId, o.id, false, nil)
        return nil, 'store_broke'
    end

    Bridge.money.add(src, total)
    Db.execute('UPDATE sovereign_store_buy_orders SET qty_filled = qty_filled + ? WHERE id = ?', { qty, o.id })

    -- pause anything the store can no longer honour
    local left = Ledger.balance(storeId, 'operating')
    if left < unit then BuyOrders.setActive(storeId, o.id, false, nil) end
    if (o.qty_filled + qty) >= o.qty_wanted then
        BuyOrders.setActive(storeId, o.id, false, nil)
    end

    local s = PStores.get(storeId)
    EventLog.write(storeId, 'buy_order_filled', charid, nil, { item = o.item, qty = qty, total = total })
    Webhooks.fire(storeId, 'purchase', {
        title = _U('wh_buy_order_filled'), color = 0x8A5C2E,
        fields = {
            { name = _U('wh_store'), value = s and s.name or tostring(storeId) },
            { name = _U('wh_item'), value = ('%s x%d'):format(o.item, qty) },
            { name = _U('wh_amount'), value = ('$%.2f'):format(total) },
        },
    })
    TriggerEvent('sovereign_stores:itemSold', { src = src, store = 'p:' .. storeId, item = o.item, qty = qty, total = total })
    return total
end

Boot.buyorders = true
