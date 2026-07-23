--[[=====================================================================
  SOVEREIGN STORES · NPC STORE DEFINITIONS
  ---------------------------------------------------------------------
  Government-run stores. Defined entirely here — never ownable, no DB
  rows. One definition can be stamped onto many map locations.

  Every item must exist in the `items` DB table; boot validates each
  catalog entry with a loud console warning for typos (invalid entries
  are dropped, the store still runs).

  Prices are dollars (cash only — owner decision 2026-07-23). Stores are
  24/7 (no hours system). NPC stock is infinite.

  Catalog entry fields:
    item      (required) DB item name
    price     (required) unit price in dollars
    category  (optional) storefront tab, defaults 'general'
    label     (optional) override the DB label
  Sell entry extras:
    minCondition      (optional) 0-100; degradable items below this are refused
    scaleByCondition  (optional) true = payout × condition% (design B8)
  Weapon entries (buy only, Phase 2 for player stores; allowed here too):
    weapon = true — item is a WEAPON_ hash; delivered via createWeapon
=====================================================================]]--

NPCStores = {

    general = {
        enabled  = true,
        label    = 'General Store',
        category = 'general',
        est      = 'EST. 1899 · SOVEREIGN COUNTY',   -- masthead eyebrow line
        tagline  = 'Provisions, supplies & honest trade',
        notice   = nil,   -- optional "Today's notice" card text in the storefront
        npcModel = 'U_M_M_NbxGeneralStoreOwner_01',
        blip     = { sprite = 1475879922, label = 'General Store' },
        roaming  = false,
        locations = {
            -- proven placements carried over from vorp_stores
            { coords = vector3(-324.628, 803.9818, 116.88), heading = -81.17, npcModel = 'U_M_M_NbxGeneralStoreOwner_01' }, -- Valentine
            { coords = vector3(1330.227, -1293.41, 76.021), heading = 68.88,  npcModel = 'S_M_M_UNIBUTCHERS_01' },          -- Rhodes
            { coords = vector3(-1789.66, -387.918, 159.32), heading = 56.96,  npcModel = 'S_M_M_UNIBUTCHERS_01' },          -- Strawberry
            { coords = vector3(-784.738, -1321.73, 42.884), heading = 179.63, npcModel = 'S_M_M_UNIBUTCHERS_01' },          -- Blackwater
        },
        categories = {
            { key = 'drinks',  label = 'Drinks' },
            { key = 'food',    label = 'Provisions' },
            { key = 'general', label = 'Sundries' },
        },
        -- EXAMPLE CATALOG — items verified to exist on the dev DB.
        -- Operators: expand freely; boot will call out any bad names.
        buy = {
            { item = 'alcohol',                  price = 2.50, category = 'drinks' },
            { item = 'consumable_raspberrywater', price = 0.75, category = 'drinks' },
            { item = 'ammorevolvernormal',       price = 0.15, category = 'general' },
        },
        sell = {
            { item = 'aligatormeat', price = 0.90, category = 'food', minCondition = 25, scaleByCondition = true },
        },
        allowedJobs = nil,   -- nil/empty = everyone; e.g. { 'doctor' }
        jobGrade    = 0,
        priceDrift  = nil,   -- optional { min = -10, max = 10 } percent, re-rolled each restart
    },

    fishing = {
        enabled  = false,    -- TODO(operator): placements + catalog, then enable
        label    = 'Fishing Supply',
        category = 'fishing',
        npcModel = 'U_M_M_NbxGeneralStoreOwner_01',
        blip     = { sprite = 1475879922, label = 'Fishing Supply' },
        roaming  = false,
        locations = {},
        categories = { { key = 'general', label = 'Tackle' } },
        buy = {}, sell = {},
    },

    pelts = {
        enabled  = false,    -- TODO(operator): placements + catalog, then enable
        label    = 'Pelt Trader',
        category = 'pelts',
        npcModel = 'S_M_M_UNIBUTCHERS_01',
        blip     = { sprite = 1475879922, label = 'Pelt Trader' },
        roaming  = false,
        locations = {},
        categories = { { key = 'general', label = 'Hides & Pelts' } },
        buy = {}, sell = {},
    },

    butcher = {
        enabled  = false,    -- TODO(operator): placements + catalog, then enable
        label    = 'Butcher',
        category = 'butcher',
        npcModel = 'S_M_M_UNIBUTCHERS_01',
        blip     = { sprite = 1475879922, label = 'Butcher' },
        roaming  = false,
        locations = {},
        categories = { { key = 'general', label = 'Meats' } },
        buy = {}, sell = {},
    },

    blackmarket = {
        enabled  = false,    -- TODO(operator): real wilderness spots in the pool, then enable
        label    = 'A Quiet Dealer',
        category = 'blackmarket',
        npcModel = 'U_M_M_ODDFELLOWSPARTICIPANT_01',
        blip     = nil,      -- roaming stores NEVER get a blip (design §2.1)
        roaming  = true,
        -- The server picks ONE pool spot at each restart (same for everyone),
        -- skipping any that fall inside Config.ExclusionZones below.
        locationPool = {
            -- { coords = vector3(0.0, 0.0, 0.0), heading = 0.0 },  -- TODO(operator)
        },
        locations  = {},     -- unused for roaming stores
        categories = { { key = 'general', label = 'No Questions' } },
        buy = {}, sell = {},
    },
}

-- Town exclusion zones: a roaming store will never set up inside these.
-- Shared by every future roaming store. Radii are deliberately generous;
-- tune freely — a console warning flags any pool spot that lands inside.
Config.ExclusionZones = {
    { name = 'Valentine',   center = vector3(-290.0, 790.0, 118.0),   radius = 220.0 },
    { name = 'Rhodes',      center = vector3(1290.0, -1300.0, 77.0),  radius = 220.0 },
    { name = 'Saint Denis', center = vector3(2600.0, -1300.0, 46.0),  radius = 450.0 },
    { name = 'Blackwater',  center = vector3(-800.0, -1300.0, 43.0),  radius = 260.0 },
    { name = 'Strawberry',  center = vector3(-1780.0, -370.0, 157.0), radius = 200.0 },
    { name = 'Annesburg',   center = vector3(2900.0, 1400.0, 44.0),   radius = 240.0 },
    { name = 'Van Horn',    center = vector3(2960.0, 550.0, 44.0),    radius = 200.0 },
    { name = 'Tumbleweed',  center = vector3(-5510.0, -2950.0, -2.0), radius = 240.0 },
    { name = 'Armadillo',   center = vector3(-3650.0, -2600.0, -14.0),radius = 220.0 },
}

-- How close a player must be to a register to browse/buy (server-verified).
Config.InteractDistance = 3.0
Config.ServerTradeDistance = 12.0   -- anti-cheat tolerance on the server side
