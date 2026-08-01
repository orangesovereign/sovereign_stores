--[[=====================================================================
  NPC STORE · GENERAL STORE
  ---------------------------------------------------------------------
  ONE catalog, MANY counters. Every location listed below sells exactly
  these items at these prices — edit the catalog once and every general
  store in the county changes together.

  Field reference lives in config/npc_stores.lua.
=====================================================================]]--

NPCStores = NPCStores or {}

NPCStores.general = {
    enabled  = true,
    label    = 'General Store',
    category = 'general',
    est      = 'EST. 1875 · SOVEREIGN COUNTY',   -- masthead eyebrow line
    tagline  = 'Provisions, supplies & honest trade',
    notice   = nil,   -- optional "Today's notice" card text in the storefront
    npcModel = 'U_M_M_NbxGeneralStoreOwner_01',
    blip     = { sprite = 1475879922, label = 'General Store' },
    roaming  = false,

    -- ── Counters ────────────────────────────────────────────────────
    -- Each entry is its own storefront on the map. npcModel/blip here
    -- override the store-wide ones above.
    locations = {
        -- proven placements carried over from vorp_stores
        { coords = vector3(-324.628, 803.9818, 116.88), heading = -81.17, npcModel = 'U_M_M_NbxGeneralStoreOwner_01' }, -- Valentine
        { coords = vector3(1330.227, -1293.41, 76.021), heading = 68.88,  npcModel = 'S_M_M_UNIBUTCHERS_01' },          -- Rhodes
        { coords = vector3(-1789.66, -387.918, 159.32), heading = 56.96,  npcModel = 'S_M_M_UNIBUTCHERS_01' },          -- Strawberry
        { coords = vector3(-784.738, -1321.73, 42.884), heading = 179.63, npcModel = 'S_M_M_UNIBUTCHERS_01' },          -- Blackwater
        { coords = vector3(-5491.22, -2938.06, -0.45),  heading = 271.22 },                                             -- Tumbleweed
        { coords = vector3(-3681.19, -2626.9,  -13.48), heading = 24.89 },                                              -- Armadillo
    },

    -- ── Storefront departments (the left rail) ───────────────────────
    categories = {
        { key = 'drinks',  label = 'Drinks' },
        { key = 'food',    label = 'Provisions' },
        { key = 'general', label = 'Sundries' },
    },

    -- ── What the county sells here ──────────────────────────────────
    buy = {
        { item = 'beefjerky',               price = 5.25, category = 'food' },
        { item = 'whisky',                  price = 10,   category = 'drinks' },
        { item = 'ammorevolvernormal',      price = 0.15, category = 'general' },
        { item = 'consumable_chickenpie',   price = 7.50, category = 'food' },
        { item = 'consumable_salmon_can',   price = 0.55, category = 'food' },
        { item = 'tequila',                 price = 12,   category = 'drinks' },
        { item = 'consumable_haycube',      price = 1.15, category = 'general' },
        { item = 'horsebrush',              price = 8,    category = 'general' },
        { item = 'horsemeal',               price = 11,   category = 'general' },
        { item = 'ammoriflenormal',         price = 8,    category = 'general' },
    },

    -- ── What the clerk buys back ────────────────────────────────────
    sell = {
        { item = 'aligatormeat', price = 0.90, category = 'food', minCondition = 25, scaleByCondition = true },
    },

    allowedJobs = nil,   -- nil/empty = everyone; e.g. { 'doctor' }
    jobGrade    = 0,
    priceDrift  = nil,   -- optional { min = -10, max = 10 } percent, re-rolled each restart
}
