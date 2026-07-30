--[[=====================================================================
  SOVEREIGN STORES · ANALYTICS (features H5, H7)

  The ledger is the MONEY (one row per transaction). This module reads
  sovereign_store_sale_items — the GOODS, one row per line — so the
  county and every owner can answer "how much, when, and what sold".

  record() is called from the transaction engine at the moment goods
  change hands; everything else here only reads.

  Owner view (H7): one store, quick 7/30-day pulse + top items.
  Bureau view (H5): the whole county — volume over time, top items,
  wage spend, tax collected, buy-order activity.
=====================================================================]]--

Analytics = {}

---Write one line of a completed transaction. Never raises: analytics must
---never be able to fail a sale.
---@param opts table { storeId?, storeKey?, kind, item, qty, unitPrice, gross, charid? }
function Analytics.record(opts)
    if type(opts) ~= 'table' then return end
    local ok = pcall(function()
        Db.insert(
            [[INSERT INTO sovereign_store_sale_items
              (store_id, store_key, kind, item, qty, unit_price, gross, charid)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
            {
                opts.storeId, opts.storeKey, opts.kind or 'sale',
                tostring(opts.item), math.floor(tonumber(opts.qty) or 0),
                Util.round2(opts.unitPrice or 0), Util.round2(opts.gross or 0),
                opts.charid,
            })
    end)
    if not ok then Util.warn('analytics: a sale line failed to record (the sale itself is unaffected)') end
end

-- ── Owner mini-analytics (H7) ───────────────────────────────────────

---Compact per-store pulse: sales/purchase totals over 7 and 30 days,
---plus the store's own top sellers.
function Analytics.forStore(storeId)
    storeId = tonumber(storeId)
    local function window(days, kind)
        local r = Db.query(
            [[SELECT COALESCE(SUM(gross),0) AS gross, COALESCE(SUM(qty),0) AS units,
                     COUNT(*) AS lines
              FROM sovereign_store_sale_items
              WHERE store_id = ? AND kind = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)]],
            { storeId, kind, days })
        local row = r and r[1] or {}
        return {
            gross = Util.round2(tonumber(row.gross) or 0),
            units = tonumber(row.units) or 0,
            lines = tonumber(row.lines) or 0,
        }
    end

    local topItems = Db.query(
        [[SELECT item, SUM(qty) AS units, SUM(gross) AS gross
          FROM sovereign_store_sale_items
          WHERE store_id = ? AND kind = 'sale' AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
          GROUP BY item ORDER BY gross DESC LIMIT 5]], { storeId }) or {}

    return {
        sales7  = window(7, 'sale'),
        sales30 = window(30, 'sale'),
        buys30  = window(30, 'purchase'),
        topItems = topItems,
    }
end

-- ── Bureau county-wide analytics (H5) ───────────────────────────────

---Daily gross for the county over `days`, both directions.
local function dailySeries(days)
    local rows = Db.query(
        [[SELECT DATE(created_at) AS d, kind, COALESCE(SUM(gross),0) AS gross
          FROM sovereign_store_sale_items
          WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
          GROUP BY DATE(created_at), kind]], { days - 1 }) or {}
    local byDay = {}
    for _, r in ipairs(rows) do
        local key = tostring(r.d)
        byDay[key] = byDay[key] or { sale = 0, purchase = 0 }
        byDay[key][r.kind] = Util.round2(tonumber(r.gross) or 0)
    end
    local series = {}
    for i = days - 1, 0, -1 do
        local d = tostring(Db.scalar('SELECT DATE_SUB(CURDATE(), INTERVAL ? DAY)', { i }))
        local cell = byDay[d] or { sale = 0, purchase = 0 }
        series[#series + 1] = { day = d:sub(6), sales = cell.sale or 0, purchases = cell.purchase or 0 }
    end
    return series
end

function Analytics.county(days)
    days = tonumber(days) or 30
    local totals = Db.query(
        [[SELECT
            COALESCE(SUM(CASE WHEN kind='sale' THEN gross END),0) AS sales,
            COALESCE(SUM(CASE WHEN kind='purchase' THEN gross END),0) AS purchases,
            COALESCE(SUM(CASE WHEN kind='sale' THEN qty END),0) AS units
          FROM sovereign_store_sale_items
          WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)]], { days })
    local t = totals and totals[1] or {}

    local topItems = Db.query(
        [[SELECT item, SUM(qty) AS units, SUM(gross) AS gross
          FROM sovereign_store_sale_items
          WHERE kind = 'sale' AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
          GROUP BY item ORDER BY gross DESC LIMIT 8]], { days }) or {}

    local topStores = Db.query(
        [[SELECT si.store_id, s.name AS store_name, s.code, SUM(si.gross) AS gross, SUM(si.qty) AS units
          FROM sovereign_store_sale_items si
          LEFT JOIN sovereign_stores s ON s.id = si.store_id
          WHERE si.kind = 'sale' AND si.store_id IS NOT NULL
            AND si.created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
          GROUP BY si.store_id ORDER BY gross DESC LIMIT 8]], { days }) or {}

    local wages = Db.scalar(
        [[SELECT COALESCE(SUM(-amount),0) FROM sovereign_store_ledger
          WHERE type = 'wage' AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)]], { days }) or 0
    local tax = Db.scalar(
        [[SELECT COALESCE(SUM(amount),0) FROM sovereign_government_fund
          WHERE type = 'tax' AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)]], { days }) or 0
    local buyOrders = Db.query(
        [[SELECT COALESCE(SUM(gross),0) AS gross, COALESCE(SUM(qty),0) AS units
          FROM sovereign_store_sale_items
          WHERE kind = 'purchase' AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)]], { days })
    local bo = buyOrders and buyOrders[1] or {}

    return {
        ok = true, days = days,
        totals = {
            sales = Util.round2(tonumber(t.sales) or 0),
            purchases = Util.round2(tonumber(t.purchases) or 0),
            units = tonumber(t.units) or 0,
            wages = Util.round2(tonumber(wages) or 0),
            taxCollected = Util.round2(tonumber(tax) or 0),
            buyOrderSpend = Util.round2(tonumber(bo.gross) or 0),
            buyOrderUnits = tonumber(bo.units) or 0,
        },
        series = dailySeries(math.min(days, 30)),
        topItems = topItems,
        topStores = topStores,
    }
end

Boot.analytics = true
