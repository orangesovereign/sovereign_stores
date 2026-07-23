--[[=====================================================================
  STORE PROBE · CLIENT SIDE  (TP-1)
  Confirms the readable client exports actually behave at runtime and
  reports character statebag availability. Results echo to the server
  console so everything is copyable from one place.
=====================================================================]]--

local INV = 'vorp_inventory'
local lines = {}

local function note(ok, label, extra)
    lines[#lines + 1] = ('%s %s %s'):format(ok and 'YES' or 'no ', label, extra or '')
end

RegisterNetEvent('sovereign_storeprobe:client', function()
    lines = {}

    -- statebag character data (for storefront money display)
    local ok, state = pcall(function() return LocalPlayer.state.Character end)
    if ok and type(state) == 'table' then
        note(true, 'LocalPlayer.state.Character', ('Money=%s Job=%s Grade=%s CharId=%s'):format(
            tostring(state.Money), tostring(state.Job), tostring(state.Grade), tostring(state.CharId)))
    else
        note(false, 'LocalPlayer.state.Character', tostring(state))
    end
    local okS, inSession = pcall(function() return LocalPlayer.state.IsInSession end)
    note(okS, 'LocalPlayer.state.IsInSession', tostring(inSession))

    -- readable client exports
    local okItems, items = pcall(function() return exports[INV]:getInventoryItems() end)
    if okItems and type(items) == 'table' then
        local n = 0
        for _ in pairs(items) do n = n + 1 end
        note(true, 'client getInventoryItems()', ('%d entries'):format(n))
    else
        note(false, 'client getInventoryItems()', tostring(items))
    end

    local okLbl, lbl = pcall(function() return exports[INV]:getWeaponDefaultLabel('WEAPON_MELEE_KNIFE') end)
    note(okLbl, 'client getWeaponDefaultLabel(WEAPON_MELEE_KNIFE)', tostring(lbl))

    local okClose = pcall(function() return exports[INV]:closeInventory() end)
    note(okClose, 'client closeInventory()', '(called while nothing open — should be harmless)')

    TriggerServerEvent('sovereign_storeprobe:results', lines)
end)
