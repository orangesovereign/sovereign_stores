--[[=====================================================================
  SOVEREIGN STORES · CONFIG VALIDATION
  Validate.run() returns an array of human-readable problems (empty = green).
  Called at boot by server/core.lua and echoed by /stores_diag.

  The point is a LOUD, SPECIFIC failure at boot instead of a mysterious
  runtime error later. Every check names the exact config key and what it
  expects.
=====================================================================]]--

Validate = {}

local function isNum(v) return type(v) == 'number' end
local function isStr(v) return type(v) == 'string' end

function Validate.run()
    local problems = {}
    local function bad(msg) problems[#problems + 1] = msg end

    if type(Config) ~= 'table' then
        return { 'Config table missing entirely — config/config.lua failed to load' }
    end

    -- ── Core ────────────────────────────────────────────────────────
    if not isStr(Config.Locale) or not (Locales and Locales[Config.Locale]) then
        bad(('Config.Locale "%s" has no matching file in config/locales/'):format(tostring(Config.Locale)))
    end
    if type(Config.AdminGroups) ~= 'table' or #Config.AdminGroups == 0 then
        bad('Config.AdminGroups must be a non-empty list (e.g. { "admin" })')
    end
    if not isStr(Config.AdminAce) or Config.AdminAce == '' then
        bad('Config.AdminAce must be a non-empty ace string')
    end
    if not isNum(Config.MaxEmployees) or Config.MaxEmployees < 0 then
        bad('Config.MaxEmployees must be a number >= 0')
    end
    if not isNum(Config.MaxCoOwners) or Config.MaxCoOwners < 0 then
        bad('Config.MaxCoOwners must be a number >= 0')
    end
    if not isStr(Config.StorageIdPrefix) or Config.StorageIdPrefix == '' then
        bad('Config.StorageIdPrefix must be a non-empty string')
    end
    if not isNum(Config.StorageSlots) or Config.StorageSlots < 1 then
        bad('Config.StorageSlots must be a number >= 1')
    end

    -- ── Scheduler sections ──────────────────────────────────────────
    if type(Config.Tax) ~= 'table' then bad('Config.Tax section missing')
    else
        if not isNum(Config.Tax.GraceHours) or Config.Tax.GraceHours < 0 then
            bad('Config.Tax.GraceHours must be a number >= 0 (0 seizes on the first miss — be sure)')
        end
        if not isNum(Config.Tax.PeriodDays) or Config.Tax.PeriodDays < 1 then
            bad('Config.Tax.PeriodDays must be a number >= 1')
        end
        if not isNum(Config.Tax.CheckMinutes) or Config.Tax.CheckMinutes < 1 then
            bad('Config.Tax.CheckMinutes must be a number >= 1')
        end
    end

    if type(Config.Inactivity) ~= 'table' then bad('Config.Inactivity section missing')
    else
        local iv = Config.Inactivity
        if not isNum(iv.WarnDays) or iv.WarnDays < 1 then
            bad('Config.Inactivity.WarnDays must be a number >= 1')
        end
        if not isNum(iv.RepossessDays) or iv.RepossessDays < 1 then
            bad('Config.Inactivity.RepossessDays must be a number >= 1')
        end
        if isNum(iv.WarnDays) and isNum(iv.RepossessDays) and iv.RepossessDays <= iv.WarnDays then
            bad('Config.Inactivity.RepossessDays must be GREATER than WarnDays (warn first, then seize)')
        end
    end

    if type(Config.Presence) ~= 'table' then bad('Config.Presence section missing')
    else
        local p = Config.Presence
        if not isNum(p.TickSeconds) or p.TickSeconds < 5 then
            bad('Config.Presence.TickSeconds must be a number >= 5')
        end
        if not isNum(p.RadiusMeters) or p.RadiusMeters <= 0 then
            bad('Config.Presence.RadiusMeters must be a positive number')
        end
        if not isNum(p.GraceTicks) or p.GraceTicks < 0 then
            bad('Config.Presence.GraceTicks must be a number >= 0')
        end
    end

    if type(Config.Wages) ~= 'table' then bad('Config.Wages section missing')
    elseif not isNum(Config.Wages.DailyMinMinutes) or Config.Wages.DailyMinMinutes < 0 then
        bad('Config.Wages.DailyMinMinutes must be a number >= 0')
    end

    if type(Config.BuyOrders) ~= 'table' then bad('Config.BuyOrders section missing')
    else
        if not isNum(Config.BuyOrders.MaxPerStore) or Config.BuyOrders.MaxPerStore < 1 then
            bad('Config.BuyOrders.MaxPerStore must be a number >= 1')
        end
        if not isNum(Config.BuyOrders.MaxQtyEach) or Config.BuyOrders.MaxQtyEach < 1 then
            bad('Config.BuyOrders.MaxQtyEach must be a number >= 1')
        end
    end

    -- ── Interaction distances ───────────────────────────────────────
    if not isNum(Config.InteractDistance) or Config.InteractDistance <= 0 then
        bad('Config.InteractDistance must be a positive number (in config/npc_stores.lua)')
    end
    if not isNum(Config.ServerTradeDistance) or Config.ServerTradeDistance <= 0 then
        bad('Config.ServerTradeDistance must be a positive number')
    end
    if isNum(Config.InteractDistance) and isNum(Config.ServerTradeDistance)
        and Config.ServerTradeDistance < Config.InteractDistance then
        bad('Config.ServerTradeDistance should be >= InteractDistance (server tolerance must not be tighter than the client prompt)')
    end

    -- ── Curated pickers ─────────────────────────────────────────────
    if type(Config.CashierPeds) ~= 'table' or #Config.CashierPeds == 0 then
        bad('Config.CashierPeds must be a non-empty list of ped groups')
    else
        for gi, group in ipairs(Config.CashierPeds) do
            if type(group.peds) ~= 'table' or #group.peds == 0 then
                bad(('Config.CashierPeds[%d] (%s) has no peds'):format(gi, tostring(group.label or group.key)))
            end
            for _, ped in ipairs(group.peds or {}) do
                if not isStr(ped.model) or ped.model == '' then
                    bad(('Config.CashierPeds: a ped in "%s" has no model'):format(tostring(group.label)))
                end
            end
        end
    end

    if type(Config.WeaponCatalog) ~= 'table' then
        bad('Config.WeaponCatalog must be a table (may be empty)')
    else
        for _, w in ipairs(Config.WeaponCatalog) do
            if not isStr(w.name) or not w.name:find('^WEAPON_') then
                bad(('Config.WeaponCatalog: "%s" is not a WEAPON_ name'):format(tostring(w.name)))
            end
            if not isNum(w.base) or w.base < 0 then
                bad(('Config.WeaponCatalog: %s needs a base price >= 0'):format(tostring(w.name)))
            end
        end
    end

    -- ── Blip catalog keys must be unique per category (owner-selectable) ─
    if type(Config.BlipCatalog) == 'table' then
        local function checkKeys(list, where)
            local seen = {}
            for _, o in ipairs(list or {}) do
                if not isStr(o.key) or o.key == '' then
                    bad(('Config.BlipCatalog.%s has an option with no key'):format(where))
                elseif seen[o.key] then
                    bad(('Config.BlipCatalog: duplicate blip key "%s" (keys must be unique per store\'s option set)'):format(o.key))
                else
                    seen[o.key] = true
                end
                if not isStr(o.sprite) and not isNum(o.sprite) then
                    bad(('Config.BlipCatalog.%s option "%s" needs a sprite'):format(where, tostring(o.key)))
                end
            end
            return seen
        end
        -- a store sees its category options + the universal set; the union
        -- must have unique keys or the picker can't tell them apart
        for cat, list in pairs(Config.BlipCatalog.categories or {}) do
            local seen = checkKeys(list, 'categories.' .. cat)
            for _, o in ipairs(Config.BlipCatalog.universal or {}) do
                if seen[o.key] then
                    bad(('Config.BlipCatalog: universal key "%s" collides with a categories.%s key'):format(o.key, cat))
                end
            end
        end
        checkKeys(Config.BlipCatalog.universal, 'universal')
    end

    -- ── NPC store definitions (config/stores/*.lua) ─────────────────
    -- NPCStores is optional (a server may run player stores only). We only
    -- flag stores that are ENABLED but can't actually work — a
    -- misconfiguration — never the mere absence of NPC stores.
    if type(NPCStores) == 'table' then
        for key, def in pairs(NPCStores) do
            if type(def) ~= 'table' then
                bad(('NPCStores.%s is not a table'):format(tostring(key)))
            elseif def.enabled then
                if not def.roaming and (type(def.locations) ~= 'table' or #def.locations == 0) then
                    bad(('NPCStores.%s is enabled but has no locations'):format(key))
                end
                if def.roaming and (type(def.locationPool) ~= 'table' or #def.locationPool == 0) then
                    bad(('NPCStores.%s is a roaming store with an empty locationPool'):format(key))
                end
                for _, e in ipairs(def.buy or {}) do
                    if not isStr(e.item) then bad(('NPCStores.%s buy entry missing item name'):format(key)) end
                    if not isNum(e.price) or e.price < 0 then
                        bad(('NPCStores.%s: "%s" needs price >= 0'):format(key, tostring(e.item)))
                    end
                end
            end

            -- Catalog SHAPE, checked whether or not the store is enabled.
            -- A stray extra `buy = {` wrapping the list is still valid Lua —
            -- it just nests every item one level too deep, so ipairs finds
            -- nothing and the shelves come up empty with no error anywhere.
            -- That cost a live debugging session; it names itself now.
            if type(def) == 'table' then
                for _, which in ipairs({ 'buy', 'sell' }) do
                    local list = def[which]
                    if list ~= nil then
                        if type(list) ~= 'table' then
                            bad(('NPCStores.%s: %s must be a list of entries'):format(key, which))
                        else
                            local arrayN, total = #list, 0
                            for _ in pairs(list) do total = total + 1 end
                            if total > arrayN then
                                bad(('NPCStores.%s: the %s catalog has named keys — an entry is nested '
                                     .. 'one level too deep (look for a stray "%s = {" wrapping the list). '
                                     .. 'Only %d of %d entries will ever be read.')
                                    :format(key, which, which, arrayN, total))
                            end
                        end
                    end
                end
            end
        end
    end

    return problems
end
