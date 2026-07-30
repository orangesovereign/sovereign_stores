--[[=====================================================================
  NPC STORE · FISHING SUPPLY
  ---------------------------------------------------------------------
  ONE catalog, MANY counters. Add each tackle shop to `locations` and
  they all trade from the same list below.

  Field reference lives in config/npc_stores.lua.
=====================================================================]]--

NPCStores = NPCStores or {}

NPCStores.fishing = {
    enabled  = false,    -- TODO(operator): placements + catalog, then flip to true
    label    = 'Fishing Supply',
    category = 'fishing',
    est      = 'EST. 1875 · SOVEREIGN COUNTY',
    tagline  = 'Rod, line & patience',
    notice   = nil,
    npcModel = 'U_M_M_NbxGeneralStoreOwner_01',
    blip     = { sprite = 1475879922, label = 'Fishing Supply' },
    roaming  = false,

    locations = {
        -- { coords = vector3(0.0, 0.0, 0.0), heading = 0.0 },   -- TODO(operator)
    },

    categories = {
        { key = 'general', label = 'Tackle' },
        { key = 'bait',    label = 'Bait' },
    },

    buy  = {},
    sell = {},

    allowedJobs = nil,
    jobGrade    = 0,
    priceDrift  = nil,
}
