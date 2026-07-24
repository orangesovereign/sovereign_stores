--[[=====================================================================
  SOVEREIGN STORES · SHELF STOCK (features D3/D4)
  The shelf is what buyers see: rows in sovereign_store_stock. The
  physical goods sit in the store's custom-inventory back room; shelving
  moves them shelf-ward, unshelving moves them back.

  v1 shelves aggregate by item NAME (metadata-carrying goods stay in
  the back room until the metadata-shelf slice lands with buy orders —
  the escrowed removeItemFromCustomInventory picks stacks itself, so
  per-stack shelf identity can't be guaranteed yet).
=====================================================================]]--

Stock = {}

function Stock.list(storeId)
    return Db.query(
        'SELECT id, item, quantity, price, sale_percent, sale_ends_at, category FROM sovereign_store_stock WHERE store_id = ? ORDER BY category, item',
        { storeId }) or {}
end

local function row(storeId, item)
    local rows = Db.query(
        'SELECT id, quantity, price, category FROM sovereign_store_stock WHERE store_id = ? AND item = ? LIMIT 1',
        { storeId, item })
    return rows and rows[1] or nil
end

---Move goods back room → shelf, setting price/category on the way.
function Stock.shelve(storeId, item, qty, price, category)
    qty = math.floor(tonumber(qty) or 0)
    price = Util.round2(tonumber(price) or -1)
    if qty < 1 or price < 0 then return false, 'bad_input' end

    local have = Bridge.storage.count(storeId, item)
    if have < qty then return false, 'not_in_storage' end
    if not Bridge.storage.removeItem(storeId, item, qty) then return false, 'storage_refused' end

    local existing = row(storeId, item)
    if existing then
        Db.execute('UPDATE sovereign_store_stock SET quantity = quantity + ?, price = ?, category = ? WHERE id = ?',
            { qty, price, category or existing.category, existing.id })
    else
        Db.insert('INSERT INTO sovereign_store_stock (store_id, item, quantity, price, category) VALUES (?, ?, ?, ?, ?)',
            { storeId, item, qty, price, category or 'general' })
    end
    return true
end

---Move goods shelf → back room.
function Stock.unshelve(storeId, item, qty, charid)
    qty = math.floor(tonumber(qty) or 0)
    if qty < 1 then return false, 'bad_input' end
    local existing = row(storeId, item)
    if not existing or existing.quantity < qty then return false, 'not_on_shelf' end
    if not Bridge.storage.addItems(storeId, { { name = item, amount = qty } }, charid) then
        return false, 'storage_refused'
    end
    if existing.quantity == qty then
        Db.execute('DELETE FROM sovereign_store_stock WHERE id = ?', { existing.id })
    else
        Db.execute('UPDATE sovereign_store_stock SET quantity = quantity - ? WHERE id = ?', { qty, existing.id })
    end
    return true
end

function Stock.setPrice(storeId, item, price)
    price = Util.round2(tonumber(price) or -1)
    if price < 0 then return false, 'bad_price' end
    local n = Db.execute('UPDATE sovereign_store_stock SET price = ? WHERE store_id = ? AND item = ?',
        { price, storeId, item })
    return (n or 0) > 0
end

---Start a timed sale (design §8.2). minutes from now; percent 1-90.
function Stock.setSale(storeId, item, percent, minutes)
    percent = math.floor(tonumber(percent) or 0)
    minutes = math.floor(tonumber(minutes) or 0)
    if percent < 1 or percent > 90 or minutes < 1 then return false, 'bad_sale' end
    local n = Db.execute(
        'UPDATE sovereign_store_stock SET sale_percent = ?, sale_ends_at = DATE_ADD(NOW(), INTERVAL ? MINUTE) WHERE store_id = ? AND item = ?',
        { percent, minutes, storeId, item })
    return (n or 0) > 0
end

function Stock.clearSale(storeId, item)
    Db.execute('UPDATE sovereign_store_stock SET sale_percent = NULL, sale_ends_at = NULL WHERE store_id = ? AND item = ?',
        { storeId, item })
    return true
end

---Server-authoritative purchase decrement. Refuses overdraw.
function Stock.take(storeId, item, qty)
    local n = Db.execute(
        'UPDATE sovereign_store_stock SET quantity = quantity - ? WHERE store_id = ? AND item = ? AND quantity >= ?',
        { qty, storeId, item, qty })
    if (n or 0) == 0 then return false end
    Db.execute('DELETE FROM sovereign_store_stock WHERE store_id = ? AND item = ? AND quantity <= 0', { storeId, item })
    return true
end

---Expire finished sales (called lazily whenever a catalog is served).
function Stock.expireSales(storeId)
    Db.execute(
        'UPDATE sovereign_store_stock SET sale_percent = NULL, sale_ends_at = NULL WHERE store_id = ? AND sale_ends_at IS NOT NULL AND sale_ends_at <= NOW()',
        { storeId })
end

---Buyer-facing catalog for a player store: priced shelf rows with live
---item labels/descriptions, active sales, stock counts.
function Stock.catalog(storeId)
    Stock.expireSales(storeId)
    local out = {}
    for _, r in ipairs(Stock.list(storeId)) do
        if r.quantity > 0 then
            local def = Bridge.inv.getDef(r.item)
            local endsIn = nil
            if r.sale_ends_at then
                local ends = Db.scalar('SELECT GREATEST(0, TIMESTAMPDIFF(MINUTE, NOW(), ?)) ', { r.sale_ends_at })
                endsIn = tonumber(ends)
            end
            out[#out + 1] = {
                item = r.item,
                label = (def and def.label) or r.item,
                desc = def and def.desc or nil,
                price = Util.round2(r.price),
                salePercent = r.sale_percent,
                saleEndsMin = endsIn,
                category = r.category,
                stock = r.quantity,
            }
        end
    end
    return out
end
