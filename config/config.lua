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
