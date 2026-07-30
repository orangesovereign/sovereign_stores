--[[=====================================================================
  NPC STORE · A QUIET DEALER  (roaming)
  ---------------------------------------------------------------------
  The exception to the rule: a ROAMING store has no fixed counters. The
  server picks ONE spot from `locationPool` at each restart — the same
  spot for everyone — and skips any that fall inside a town exclusion
  zone (Config.ExclusionZones, in config/npc_stores.lua).

  A roaming store NEVER gets a blip (design §2.1). If you want it found,
  it has to be found by word of mouth.

  Field reference lives in config/npc_stores.lua.
=====================================================================]]--

NPCStores = NPCStores or {}

NPCStores.blackmarket = {
    enabled  = false,    -- TODO(operator): real wilderness spots in the pool, then flip to true
    label    = 'A Quiet Dealer',
    category = 'blackmarket',
    est      = nil,      -- no charter, no founding date
    tagline  = 'No questions, no receipts',
    notice   = nil,
    npcModel = 'U_M_M_ODDFELLOWSPARTICIPANT_01',
    blip     = nil,      -- roaming stores NEVER get a blip
    roaming  = true,

    locationPool = {
        -- { coords = vector3(0.0, 0.0, 0.0), heading = 0.0 },   -- TODO(operator)
    },
    locations = {},      -- unused for roaming stores

    categories = {
        { key = 'general', label = 'No Questions' },
    },

    buy  = {},
    sell = {},

    allowedJobs = nil,
    jobGrade    = 0,
    priceDrift  = nil,
}
