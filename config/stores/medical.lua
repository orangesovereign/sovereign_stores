--[[=====================================================================
  NPC STORE · MEDICAL SUPPLY
  ---------------------------------------------------------------------
  ONE catalog, MANY counters. Add each clinic supply desk to `locations`
  and they all trade from the same list below.

  Field reference lives in config/npc_stores.lua.
=====================================================================]]--

NPCStores = NPCStores or {}

NPCStores.medical = {
    enabled  = true,
    label    = 'Medical Supply',
    category = 'medical',
    est      = 'EST. 1875 · SOVEREIGN COUNTY',
    tagline  = 'Remedies, tonics & field dressings',
    notice   = nil,
    npcModel = 'u_m_m_rhddoctor_01',                 -- a physician minds the counter
    blip     = { sprite = 'blip_shop_doctor', label = 'Medical Supply' },
    roaming  = false,

    -- ── Counters ────────────────────────────────────────────────────
    locations = {
        -- Tumbleweed Medical Supply Store
        { coords = vector3(-5501.75, -2962.59, -0.76),  heading = 275.0 },
        -- Armadillo Medical Supply Store
        { coords = vector3(-3661.32, -2595.52, -13.36), heading = 185.67 },
        -- Blackwater Medical Supply
        { coords = vector3(-786.49,  -1303.15, 43.72),  heading = 87.12 },
        -- Valentine Medical Supply
        { coords = vector3(-287.99,  804.05,   119.34), heading = 271.32 },
    },

    -- ── Storefront departments (the left rail) ───────────────────────
    categories = {
        { key = 'meds',   label = 'Remedies' },
        { key = 'tonics', label = 'Tonics' },
    },

    -- ── What the county sells here ──────────────────────────────────
    -- TODO(operator): stock with your real medical item names. Each must
    -- exist in the `items` DB table — boot names (and drops) any it can't
    -- find, so the store still opens while you dial it in.
    --   { item = '<db_item_name>', price = 5.00, category = 'meds' },
    buy = {},

    -- ── What the clerk buys back (usually nothing for a supply store) ─
    sell = {},

    allowedJobs = nil,   -- nil/empty = everyone; e.g. { 'doctor' }
    jobGrade    = 0,
    priceDrift  = nil,
}
