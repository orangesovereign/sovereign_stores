--[[=====================================================================
  SOVEREIGN STORES · WEBHOOKS (feature I2)

  Two layers, one call:
    · the ADMIN webhook (Config.AdminWebhook) sees everything
    · a STORE's own webhook sees the event types its owner enabled

  Webhooks are a MIRROR. The database is the record (I1) — a dead
  webhook URL must never cost us a ledger row or an event, so every
  send is fire-and-forget and failures are logged, never raised.

  We build our own embeds rather than using Core.AddWebhook: richer
  fields, our own colours, and no dependency on core's formatting.
=====================================================================]]--

Webhooks = {}

local EVENT_TYPES <const> = {
    'sale', 'purchase', 'stock', 'staff', 'funds', 'tax', 'repossession', 'storefront',
}

function Webhooks.eventTypes() return EVENT_TYPES end

local function post(url, payload)
    if type(url) ~= 'string' or url == '' then return end
    PerformHttpRequest(url, function(status)
        if status ~= 200 and status ~= 204 then
            Util.warn(('webhook rejected (HTTP %s) — the ledger is unaffected'):format(tostring(status)))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

---Build one embed. `spec` = { title, description, color, fields, footer }
local function embed(spec)
    local fields = {}
    for _, f in ipairs(spec.fields or {}) do
        fields[#fields + 1] = {
            name = tostring(f.name),
            value = tostring(f.value),
            inline = f.inline ~= false,
        }
    end
    return {
        title = spec.title,
        description = spec.description,
        color = spec.color or 0x8A5C2E,
        fields = fields,
        footer = { text = spec.footer or _U('wh_footer') },
    }
end

---Fire an event to whichever layers want it.
---@param storeId integer|nil store the event belongs to (nil = county-wide)
---@param eventType string one of EVENT_TYPES
---@param spec table embed spec
function Webhooks.fire(storeId, eventType, spec)
    local ok, err = pcall(function()
        local payload = { username = _U('wh_username'), embeds = { embed(spec) } }

        -- admin layer: the whole county, always
        post(Config.AdminWebhook, payload)

        -- store layer: only if the owner set a URL and enabled this type
        if storeId then
            local s = PStores.get(storeId)
            if s and s.webhook_url and s.webhook_url ~= '' then
                local enabled = s.webhook_events or {}
                if enabled[eventType] == true then post(s.webhook_url, payload) end
            end
        end
    end)
    if not ok then Util.warn('webhook build failed: ' .. tostring(err)) end
end

---Owner configuration (Management → Storefront).
function Webhooks.setUrl(storeId, url, actorCharid)
    url = tostring(url or '')
    if url ~= '' and not url:match('^https://') then return false, 'bad_url' end
    Db.execute('UPDATE sovereign_stores SET webhook_url = ? WHERE id = ?',
        { url ~= '' and url or nil, storeId })
    PStores.refresh(storeId)
    EventLog.write(storeId, 'webhook_set', actorCharid, nil, { cleared = url == '' })
    return true
end

function Webhooks.toggleEvent(storeId, eventType, on, actorCharid)
    local valid = false
    for _, t in ipairs(EVENT_TYPES) do if t == eventType then valid = true break end end
    if not valid then return false, 'bad_event' end
    local s = PStores.get(storeId)
    if not s then return false, 'unknown' end
    local events = s.webhook_events or {}
    events[eventType] = on == true or nil
    Db.execute('UPDATE sovereign_stores SET webhook_events = ? WHERE id = ?', { json.encode(events), storeId })
    PStores.refresh(storeId)
    EventLog.write(storeId, 'webhook_set', actorCharid, nil, { event = eventType, on = on == true })
    return true
end

Boot.webhooks = true
