--[[=====================================================================
  SOVEREIGN STORES · NPC STORES — SHARED SETTINGS & FIELD REFERENCE
  ---------------------------------------------------------------------
  Government-run stores. Never ownable, no DB rows, infinite stock, 24/7,
  cash only.

  EACH STORE TYPE IS ITS OWN FILE in config/stores/ :

      config/stores/general.lua       ← one catalog, four counters
      config/stores/fishing.lua
      config/stores/pelts.lua
      config/stores/butcher.lua
      config/stores/blackmarket.lua   ← roaming, no blip

  That is the whole model: ONE definition per type, MANY locations. Every
  general store in the county sells the same goods at the same prices
  because they share one catalog; add a counter by adding a line to that
  file's `locations`. To add a new type, drop in a new file — the
  manifest loads config/stores/*.lua and each file appends itself to the
  NPCStores table, so load order never matters.

  Changes here need a resource restart: the config is read once at boot.
  Every item name is validated against the `items` DB table at boot —
  a typo gets a loud console warning and that one entry is dropped
  (the store still opens).

  ─── FIELD REFERENCE ─────────────────────────────────────────────────
  Store fields:
    enabled     false hides the store entirely (placements, blips, peds)
    label       name across the storefront masthead and blips
    category    drives the storefront's department icon
    est         masthead eyebrow line (nil = "~ SOVEREIGN COUNTY ~")
    tagline     italic line under the store name
    notice      optional "Today's notice" card in the department rail
    npcModel    cashier ped for every counter (a location may override)
    blip        { sprite = <hash|name>, label = <text> }; nil = no blip
    roaming     true = one pool spot picked per restart, never a blip
    locations   array of counters: { coords, heading, npcModel?, blip? }
    locationPool  roaming stores only — candidate spots
    categories  storefront departments: { { key, label }, ... }
    buy         what the store SELLS to players
    sell        what the store BUYS from players
    allowedJobs nil/empty = everyone; e.g. { 'doctor' }
    jobGrade    minimum job grade when allowedJobs is set
    priceDrift  optional { min = -10, max = 10 } percent, re-rolled each restart

  Catalog entry (buy):
    item      (required) DB item name
    price     (required) unit price in dollars
    category  (optional) which department tab, defaults 'general'
    label     (optional) override the DB label
    weapon    (optional) true = a WEAPON_ name, delivered via createWeapon

  Catalog entry (sell) — the above, plus:
    minCondition      0-100; degradable stacks below this are refused
    scaleByCondition  true = payout × the stack's condition %
=====================================================================]]--

-- Town exclusion zones: a roaming store will never set up inside these.
-- Shared by every roaming store. Radii are deliberately generous; tune
-- freely — a console warning flags any pool spot that lands inside one.
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
