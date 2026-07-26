--[[=====================================================================
  SOVEREIGN STORES · CONFIG
  Phase 0 carries only the core settings; later phases append their own
  sections (NPC store catalogs live in config/npc_stores.lua from Phase 1).
=====================================================================]]--

Config = {}

-- ── Core ────────────────────────────────────────────────────────────
Config.Debug  = false     -- verbose console logging
Config.Locale = 'en'      -- must match a file in config/locales/

-- ── Admin access (dashboard, admin commands) ────────────────────────
-- A player passes if their VORP account group is listed OR they hold the ace.
Config.AdminGroups = { 'admin' }
Config.AdminAce    = 'sovereignstores.admin'

-- ── Notifications ───────────────────────────────────────────────────
Config.NotifyTitle = 'Sovereign Stores'   -- Card title fallback

-- ── Player stores: server-wide caps (design §3, owner-approved) ─────
Config.MaxEmployees = 5
Config.MaxCoOwners  = 1

-- ── Store storage (Cas custom-inventory layer, see docs/05) ─────────
Config.StorageIdPrefix = 'sovstore_'   -- custom inventory id = prefix .. store id
Config.StorageSlots    = 30            -- default back-room capacity per store

-- ── Webhooks ────────────────────────────────────────────────────────
-- Admin layer (server-wide firehose). Empty string disables.
Config.AdminWebhook = ''

-- ── Schedulers ──────────────────────────────────────────────────────
-- All cycles are DB-dated, so a restart never skips or double-charges:
-- the worker simply catches up on anything now due.
Config.Tax = {
    GraceHours    = 72,    -- delinquency deadline after a failed collection
    CheckMinutes  = 15,    -- how often the collector sweeps for due stores
    PeriodDays    = 30,    -- one "month" of county time between collections
    -- Collection pulls the tax reserve first, then covers any shortfall from
    -- the operating ledger — both are the store's money, and a store that
    -- CAN pay should never fall delinquent on bookkeeping alone.
    UseOperatingShortfall = true,
}
Config.Inactivity = {
    WarnDays        = 30,  -- flag on dashboard + letter
    RepossessDays   = 45,  -- automatic repossession
    CoOwnerResets   = false, -- owner-based rule by default (design §6)
    CheckMinutes    = 60,  -- absence sweep interval
}

-- ── Wages (Phase 3 clock settles these at clock-out) ────────────────
Config.Wages = {
    DailyMinMinutes = 120, -- verified minutes a daily-rate shift must reach
}

-- ── Buy orders (stores buying FROM players) ─────────────────────────
Config.BuyOrders = {
    MaxPerStore = 12,
    MaxQtyEach  = 999,
}

-- ── Presence heartbeat (Phase 3 consumes) ───────────────────────────
Config.Presence = {
    TickSeconds  = 60,     -- verification interval while clocked in
    RadiusMeters = 25.0,   -- distance from register that still counts
    GraceTicks   = 2,      -- missed ticks tolerated before auto clock-out
}

-- ── Cashier peds (owner-selectable; curated, verified in
--    _reference/rdr3_discoveries/peds/peds_list.lua — never the full zoo) ──
Config.CashierPeds = {
    { key = 'shopkeepers', label = 'Shopkeepers', peds = {
        { model = 'u_m_m_valgenstoreowner_01',     label = 'Valentine Shopkeep' },
        { model = 'u_m_m_rhdgenstoreowner_01',     label = 'Rhodes Shopkeep' },
        { model = 'u_f_m_tumgeneralstoreowner_01', label = 'Frontier Shopkeep' },
    } },
    { key = 'gunsmiths', label = 'Gunsmiths', peds = {
        { model = 'u_m_m_valgunsmith_01', label = 'Valentine Gunsmith' },
        { model = 'u_m_m_rhdgunsmith_01', label = 'Rhodes Gunsmith' },
        { model = 'u_m_m_nbxgunsmith_01', label = 'City Gunsmith' },
    } },
    { key = 'butchers', label = 'Butchers', peds = {
        { model = 'u_m_m_valbutcher_01',  label = 'Valentine Butcher' },
        { model = 'u_m_m_tumbutcher_01',  label = 'Tumbleweed Butcher' },
        { model = 's_m_m_unibutchers_01', label = 'Working Butcher' },
    } },
    { key = 'barkeeps', label = 'Barkeeps', peds = {
        { model = 'u_m_m_valbartender_01', label = 'Valentine Barkeep' },
        { model = 'u_m_m_rhdbartender_01', label = 'Rhodes Barkeep' },
        { model = 'u_f_m_vhtbartender_01', label = 'Van Horn Barmaid' },
    } },
    { key = 'doctors', label = 'Doctors', peds = {
        { model = 'u_m_m_valdoctor_01', label = 'Valentine Doctor' },
        { model = 'u_m_m_rhddoctor_01', label = 'Rhodes Doctor' },
    } },
    { key = 'tradesfolk', label = 'Tradesfolk', peds = {
        { model = 's_m_m_barber_01', label = 'Barber' },
        { model = 's_m_m_tailor_01', label = 'Tailor' },
    } },
}

-- ── Weapon catalog (player gun counters; names verified against the
--    deployed Cas-inventory config/weapons.lua) ─────────────────────
Config.WeaponCatalog = {
    { name = 'WEAPON_REVOLVER_CATTLEMAN',    label = 'Cattleman Revolver',    base = 45.00 },
    { name = 'WEAPON_REVOLVER_DOUBLEACTION', label = 'Double-Action Revolver', base = 65.00 },
    { name = 'WEAPON_REVOLVER_SCHOFIELD',    label = 'Schofield Revolver',    base = 84.00 },
    { name = 'WEAPON_REPEATER_CARBINE',      label = 'Carbine Repeater',      base = 90.00 },
    { name = 'WEAPON_REPEATER_WINCHESTER',   label = 'Lancaster Repeater',    base = 135.00 },
    { name = 'WEAPON_RIFLE_SPRINGFIELD',     label = 'Springfield Rifle',     base = 120.00 },
    { name = 'WEAPON_RIFLE_BOLTACTION',      label = 'Bolt-Action Rifle',     base = 180.00 },
    { name = 'WEAPON_SHOTGUN_DOUBLEBARREL',  label = 'Double-Barrel Shotgun', base = 110.00 },
    { name = 'WEAPON_SHOTGUN_PUMP',          label = 'Pump-Action Shotgun',   base = 148.00 },
    { name = 'WEAPON_BOW',                   label = 'Hunting Bow',           base = 38.00 },
    { name = 'WEAPON_MELEE_KNIFE',           label = 'Hunting Knife',         base = 8.00 },
}

-- ── Owner-selectable map blips (curated per charter category; sprite
--    names verified in rdr3_discoveries/textures/blips). Gunsmith options
--    carry the county's brown tint — RDR3 has no named brown, so we use
--    BLIP_MODIFIER_MP_HOT_BLIP (COLOR_ORANGE), which reads burnt-brown on
--    the parchment map. Swap the modifier here if the county ever wants a
--    different shade. Keys must stay unique across the whole catalog. ──
Config.BlipCatalog = {
    universal = {
        { key = 'store', label = 'Storefront',   sprite = 'blip_shop_store' },
        { key = 'stall', label = 'Market Stall', sprite = 'blip_shop_market_stall' },
        { key = 'shady', label = 'Back-Alley',   sprite = 'blip_shop_shady_store' },
    },
    categories = {
        weapons    = {
            { key = 'gunsmith',   label = 'Gunsmith',   sprite = 'blip_shop_gunsmith',   color = 'BLIP_MODIFIER_MP_HOT_BLIP' },
            { key = 'blacksmith', label = 'Blacksmith', sprite = 'blip_shop_blacksmith', color = 'BLIP_MODIFIER_MP_HOT_BLIP' },
        },
        saloon     = { { key = 'saloon',    label = 'Saloon',       sprite = 'blip_saloon' } },
        nightclub  = {
            { key = 'nightsign', label = 'Saloon Sign',  sprite = 'blip_saloon' },
            { key = 'photo',     label = 'Photo Studio', sprite = 'blip_photo_studio' },
        },
        restaurant = { { key = 'kitchen',   label = 'Saloon Fare',  sprite = 'blip_saloon' } },
        butcher    = {
            { key = 'butcher',   label = 'Butcher',      sprite = 'blip_shop_butcher' },
            { key = 'trapper',   label = 'Trapper',      sprite = 'blip_shop_animal_trapper' },
        },
        fishing    = {
            { key = 'tackle',    label = 'Tackle Shop',  sprite = 'blip_shop_tackle' },
            { key = 'angler',    label = 'Fishing',      sprite = 'blip_mg_fishing' },
        },
        pelts      = {
            { key = 'pelts',     label = 'Trapper',      sprite = 'blip_shop_animal_trapper' },
            { key = 'peltsbutcher', label = 'Butcher',   sprite = 'blip_shop_butcher' },
        },
        animals    = {
            { key = 'horse',     label = 'Horse Dealer', sprite = 'blip_shop_horse' },
            { key = 'stable',    label = 'Stable',       sprite = 'blip_stable' },
            { key = 'critters',  label = 'Trapper',      sprite = 'blip_shop_animal_trapper' },
        },
        mining     = { { key = 'forge',     label = 'Blacksmith',   sprite = 'blip_shop_blacksmith' } },
        produce    = { { key = 'produce',   label = 'Market Stall', sprite = 'blip_shop_market_stall' } },
        tailor     = {
            { key = 'tailor',    label = 'Tailor',       sprite = 'blip_shop_tailor' },
            { key = 'barber',    label = 'Barber',       sprite = 'blip_shop_barber' },
        },
    },
}
