--[[=====================================================================
  SOVEREIGN SHOPS · CAS-INVENTORY EXPORT PROBE   (throwaway spike, TP-1)
  ---------------------------------------------------------------------
  Cas-inventory's server code is escrow-encrypted, so exact export
  signatures can't be read from source. This probe confirms them live.

  HOW TO RUN
  1. Copy this folder into the DEV server resources.
  2. Add `ensure sovereign_storeprobe` AFTER vorp_inventory (and oxmysql).
  3. Join with a character whose inventory has a little free space.
  4. Run  /storeprobe <item_name> <weapon_name>   in game
     (or  storeprobe <item_name> <weapon_name>    in the server console —
     it targets the first connected player).
     Example:  /storeprobe consumable_bread WEAPON_MELEE_KNIFE
     The item must exist in your `items` DB table; the probe tells you
     if it doesn't and suggests a few names that do.
  5. Copy EVERYTHING between the ===== marks in the SERVER console
     (plus the client-results block) back to Claude.
  6. Delete the resource afterward — it ships nothing.

  SAFETY: every call is pcall-guarded. Writes are add-then-remove pairs
  (1 test item, up to 2 test weapons — created then deleted, a throwaway
  custom inventory — registered then deleted). DB access is read-only.
=====================================================================]]--
fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'
author 'Sovereign County RP'
description 'TP-1: probes Cas-inventory (vorp_inventory 1.7.3 escrow) export signatures. Throwaway.'
version '0.1.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}
client_script 'client.lua'
