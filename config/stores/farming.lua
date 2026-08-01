--[[=====================================================================
  NPC STORE · FARMING SUPPLY
  ---------------------------------------------------------------------
  ONE catalog, MANY counters. Seed, feed and field tools. Add each
  supply counter to `locations`; they all trade from the list below.

  Field reference lives in config/npc_stores.lua.
=====================================================================]]--

NPCStores = NPCStores or {}

NPCStores.farming = {
    enabled  = true,
    label    = 'Farming Store',
    category = 'farming',
    est      = 'EST. 1875 · SOVEREIGN COUNTY',
    tagline  = 'Seed, feed & honest tools',
    notice   = nil,
    npcModel = 'a_m_m_rancher_01',                   -- a rancher minds the counter
    blip     = { sprite = 'blip_shop_market_stall', label = 'Farming Store' },
    roaming  = false,

    -- ── Counters ────────────────────────────────────────────────────
    locations = {
        -- Blackwater Farming Store
        { coords = vector3(-833.79, -1367.88, 43.67), heading = 43.83 },
    },

    -- ── Storefront departments (the left rail) ───────────────────────
    categories = {
        { key = 'seed',  label = 'Seed & Feed' },
        { key = 'tools', label = 'Tools' },
    },

    -- ── What the county sells here ──────────────────────────────────
    -- TODO(operator): stock with your real farming item names. Each must
    -- exist in the `items` DB table — boot names (and drops) any it can't
    -- find, so the store still opens while you dial it in.
    --   { item = '<db_item_name>', price = 3.00, category = 'seed' },
    buy = {},

    sell = {},

    allowedJobs = nil,
    jobGrade    = 0,
    priceDrift  = nil,
}
