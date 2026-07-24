--[[=====================================================================
  SOVEREIGN STORES · EVENT LOG (feature I1)
  Non-money events. Money movements live in the ledger; both are the
  source of truth — webhooks only mirror them (Phase 4).
=====================================================================]]--

EventLog = {}

---@param storeId number|nil  nil = server-wide/admin event
---@param kind string         hired|fired|perms_changed|wage_set|open|close|branding|assigned|code_set|price_set|tax_rate_set|transfer|repossessed|adjustment
---@param actor number|nil    charid performing the action (nil = system)
---@param target number|nil   charid acted upon
---@param data table|nil      extra context, stored as JSON
function EventLog.write(storeId, kind, actor, target, data)
    Db.insert(
        'INSERT INTO sovereign_store_events (store_id, kind, actor_charid, target_charid, data) VALUES (?, ?, ?, ?, ?)',
        { storeId, kind, actor, target, data and json.encode(data) or nil }
    )
    TriggerEvent('sovereign_stores:event', { store = storeId, kind = kind, actor = actor, target = target, data = data })
end

function EventLog.recent(storeId, limit)
    return Db.query(
        'SELECT kind, actor_charid, target_charid, data, created_at FROM sovereign_store_events WHERE store_id = ? ORDER BY id DESC LIMIT ?',
        { storeId, math.min(tonumber(limit) or 50, 200) }
    ) or {}
end
