--[[=====================================================================
  SOVEREIGN STORES · NPC STORE RUNTIME (features B1-B9)
  Builds validated runtime catalogs from config/npc_stores.lua, rolls
  price drift, picks roaming locations, and publishes placements to all
  clients through GlobalState (late joiners get it for free).
=====================================================================]]--

Npc = {
    stores     = {},   -- [key] = runtime store (validated catalog, resolved prices)
    placements = {},   -- flat array published to clients
}

local function insideExclusion(coords)
    for _, zone in ipairs(Config.ExclusionZones or {}) do
        local dx, dy = coords.x - zone.center.x, coords.y - zone.center.y
        if (dx * dx + dy * dy) <= (zone.radius * zone.radius) then
            return zone.name
        end
    end
    return nil
end

local function rollDrift(price, drift)
    if not drift then return price end
    local pct = math.random(drift.min or 0, drift.max or 0)
    return Util.round2(price * (1 + pct / 100))
end

-- Validate one catalog list against the items DB; drop unknowns loudly.
local function validateCatalog(storeKey, list, side, drift)
    local out = {}
    for _, entry in ipairs(list or {}) do
        local def = entry.weapon and true or Bridge.inv.getDef(entry.item)
        if not def then
            Util.err(('npc store "%s": %s item "%s" not in items DB — entry dropped'):format(storeKey, side, entry.item))
        elseif type(entry.price) ~= 'number' or entry.price < 0 then
            Util.err(('npc store "%s": %s item "%s" has no valid price — entry dropped'):format(storeKey, side, entry.item))
        else
            out[#out + 1] = {
                item     = entry.item,
                label    = entry.label or (type(def) == 'table' and def.label) or entry.item,
                desc     = entry.desc or (type(def) == 'table' and def.desc) or nil,
                price    = rollDrift(Util.round2(entry.price), drift),
                salePercent = entry.salePercent,   -- optional config sale, priced server-side
                category = entry.category or 'general',
                weapon   = entry.weapon or nil,
                minCondition     = entry.minCondition,
                scaleByCondition = entry.scaleByCondition or false,
            }
        end
    end
    return out
end

local function pickRoamingSpot(storeKey, def)
    local pool = {}
    for _, spot in ipairs(def.locationPool or {}) do
        local zone = insideExclusion(spot.coords)
        if zone then
            Util.warn(('npc store "%s": pool spot (%.1f, %.1f) sits inside the %s exclusion zone — clean it out of the config'):format(
                storeKey, spot.coords.x, spot.coords.y, zone))
        else
            pool[#pool + 1] = spot
        end
    end
    if #pool == 0 then
        Util.err(('npc store "%s": roaming, but no usable pool spots — store disabled this restart'):format(storeKey))
        return nil
    end
    return pool[math.random(1, #pool)]
end

function Npc.init()
    Npc.stores, Npc.placements = {}, {}
    local types, spots = 0, 0

    for key, def in pairs(NPCStores or {}) do
        if def.enabled then
            local store = {
                key        = key,
                label      = def.label or key,
                category   = def.category or 'general',
                est        = def.est,
                tagline    = def.tagline,
                notice     = def.notice,
                npcModel   = def.npcModel,
                blip       = (not def.roaming) and def.blip or nil,  -- roaming: never a blip
                roaming    = def.roaming or false,
                categories = def.categories or { { key = 'general', label = 'Goods' } },
                buy        = validateCatalog(key, def.buy, 'buy', def.priceDrift),
                sell       = validateCatalog(key, def.sell, 'sell', nil),
                allowedJobs = (def.allowedJobs and #def.allowedJobs > 0) and def.allowedJobs or nil,
                jobGrade   = def.jobGrade or 0,
                locations  = {},
            }

            if store.roaming then
                local spot = pickRoamingSpot(key, def)
                if spot then store.locations = { spot } end
            else
                store.locations = def.locations or {}
            end

            if #store.locations == 0 then
                Util.warn(('npc store "%s" enabled but has no locations — skipped'):format(key))
            else
                Npc.stores[key] = store
                types = types + 1
                for i, loc in ipairs(store.locations) do
                    spots = spots + 1
                    Npc.placements[#Npc.placements + 1] = {
                        store    = key,
                        idx      = i,
                        label    = store.label,
                        coords   = { x = loc.coords.x, y = loc.coords.y, z = loc.coords.z },
                        heading  = loc.heading or 0.0,
                        npcModel = loc.npcModel or store.npcModel,
                        blip     = store.blip,   -- nil for roaming = no blip, ever
                    }
                end
            end
        end
    end

    Npc.publishAll()
    Util.ok(('NPC stores ready: %d types, %d placements'):format(types, spots))
    return types, spots
end

---Merge NPC placements with player-store counters and publish to every
---client. Player stores: blip only while open (default hidden closed,
---design D7); cashier ped always present until the Phase 3 clock system
---swaps in real staff.
function Npc.publishAll()
    local merged = {}
    for _, p in ipairs(Npc.placements) do merged[#merged + 1] = p end
    if PStores and PStores.all then
        for id, s in pairs(PStores.all()) do
            local rc = s.register_coords
            if rc and s.status ~= 'repossessed' then
                merged[#merged + 1] = {
                    store    = 'p:' .. id,
                    idx      = 1,
                    label    = s.name,
                    coords   = { x = rc.x, y = rc.y, z = rc.z },
                    heading  = rc.h or 0.0,
                    npcModel = s.npc_model or 'U_M_M_NbxGeneralStoreOwner_01',
                    blip     = (s.status == 'open') and { sprite = 1475879922, label = s.name } or nil,
                }
            end
        end
    end
    GlobalState['sovereign_stores:placements'] = merged
end

function Npc.get(key)
    return Npc.stores[key]
end

-- Server-side proximity check (anti-cheat): is this player near any
-- placement of the store? Tolerance is deliberately generous.
function Npc.playerNear(src, storeKey)
    local store = Npc.stores[storeKey]
    if not store then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local maxD = Config.ServerTradeDistance or 12.0
    for _, loc in ipairs(store.locations) do
        local dx, dy, dz = p.x - loc.coords.x, p.y - loc.coords.y, p.z - loc.coords.z
        if (dx * dx + dy * dy + dz * dz) <= (maxD * maxD) then return true end
    end
    return false
end

function Npc.jobAllowed(src, storeKey)
    local store = Npc.stores[storeKey]
    if not store or not store.allowedJobs then return true end
    local ch = Bridge.getCharacter(src)
    if not ch then return false end
    for _, job in ipairs(store.allowedJobs) do
        if ch.job == job and (ch.jobGrade or 0) >= (store.jobGrade or 0) then return true end
    end
    return false
end
