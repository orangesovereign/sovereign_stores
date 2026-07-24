fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author 'Sovereign County RP'
description 'Unified commerce for Sovereign County: NPC stores + player-owned storefronts. Replaces vorp_stores.'
repository 'https://github.com/orangesovereign/sovereign_stores'
version '0.4.0'

-- Load order is deliberate: config → locale → util → events → validate → bridge,
-- then db.lua before anything that touches MySQL, core.lua last on each side.
shared_scripts {
    'config/config.lua',
    'config/npc_stores.lua',
    'config/locales/en.lua',
    'shared/util.lua',
    'shared/events.lua',
    'shared/perms.lua',
    'shared/validate.lua',
    'shared/bridge.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/fund.lua',
    'server/eventlog.lua',
    'server/ledger.lua',
    'server/serials.lua',
    'server/player_stores.lua',
    'server/npc_stores.lua',
    'server/admin.lua',
    'server/transactions.lua',
    'server/core.lua',
}

client_scripts {
    'client/stores.lua',
    'client/admin.lua',
    'client/nui.lua',
    'client/core.lua',
}

ui_page 'ui/dist/index.html'
files {
    'ui/dist/index.html',
    'ui/dist/assets/*',
}

-- oxmysql is deliberately not listed here (checked at runtime with a clear
-- diagnostic instead of a hard manifest failure); these four are load-order +
-- operator clarity.
dependencies {
    'vorp_core',
    'vorp_inventory',
    'sovereign_notify',
    'sovereign_menus',
}
