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

-- ── Schedulers (Phase 4 consumes; seeded here so ops can plan) ──────
Config.Tax = {
    GraceHours   = 72,     -- delinquency deadline after a failed collection
}
Config.Inactivity = {
    WarnDays        = 30,  -- flag on dashboard + letter
    RepossessDays   = 45,  -- automatic repossession
    CoOwnerResets   = false, -- owner-based rule by default (design §6)
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
