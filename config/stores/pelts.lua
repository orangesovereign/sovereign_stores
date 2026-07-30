--[[=====================================================================
  NPC STORE · PELT TRADER
  ---------------------------------------------------------------------
  ONE catalog, MANY counters. Pelt traders mostly BUY — use `sell` for
  what the trader takes off hunters, with minCondition/scaleByCondition
  so a ruined hide fetches less (or nothing).

  Field reference lives in config/npc_stores.lua.
=====================================================================]]--

NPCStores = NPCStores or {}

NPCStores.pelts = {
    enabled  = false,    -- TODO(operator): placements + catalog, then flip to true
    label    = 'Pelt Trader',
    category = 'pelts',
    est      = 'EST. 1875 · SOVEREIGN COUNTY',
    tagline  = 'Hides bought, honestly graded',
    notice   = nil,
    npcModel = 'S_M_M_UNIBUTCHERS_01',
    blip     = { sprite = 1475879922, label = 'Pelt Trader' },
    roaming  = false,

    locations = {
        -- { coords = vector3(0.0, 0.0, 0.0), heading = 0.0 },   -- TODO(operator)
    },

    categories = {
        { key = 'general', label = 'Hides & Pelts' },
    },

    buy  = {},
    sell = {},

    allowedJobs = nil,
    jobGrade    = 0,
    priceDrift  = nil,
}
