--[[=====================================================================
  NPC STORE · BUTCHER
  ---------------------------------------------------------------------
  ONE catalog, MANY counters.

  Field reference lives in config/npc_stores.lua.
=====================================================================]]--

NPCStores = NPCStores or {}

NPCStores.butcher = {
    enabled  = false,    -- TODO(operator): placements + catalog, then flip to true
    label    = 'Butcher',
    category = 'butcher',
    est      = 'EST. 1875 · SOVEREIGN COUNTY',
    tagline  = 'Cut fresh, sold fair',
    notice   = nil,
    npcModel = 'S_M_M_UNIBUTCHERS_01',
    blip     = { sprite = 1475879922, label = 'Butcher' },
    roaming  = false,

    locations = {
        -- { coords = vector3(0.0, 0.0, 0.0), heading = 0.0 },   -- TODO(operator)
    },

    categories = {
        { key = 'general', label = 'Meats' },
    },

    buy  = {},
    sell = {},

    allowedJobs = nil,
    jobGrade    = 0,
    priceDrift  = nil,
}
