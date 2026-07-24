--[[=====================================================================
  SOVEREIGN STORES · CLIENT — Store Management bridge
  /mystore (server-gated). Staff of several stores pick one through
  sovereign_menus; the panel itself is the shared NUI.
=====================================================================]]--

local mgmtOpen = false
local currentStore = nil

local function await(name, ...)
    local Core = exports.vorp_core:GetCore()
    return Core.Callback.TriggerAwait(name, ...)
end

local function openPanel(storeId)
    local res = await('sovereign_stores:mgmt:get', storeId)
    if not res or not res.ok then
        return Bridge.notify(_U('err_not_staff'))
    end
    currentStore = storeId
    mgmtOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'mgmt:open', payload = res })
end

RegisterNetEvent('sovereign_stores:openManagement', function()
    if mgmtOpen then return end
    local mine = await('sovereign_stores:mgmt:myStores')
    if not mine or not mine.ok or #mine.stores == 0 then
        return Bridge.notify(_U('err_not_staff'))
    end
    if #mine.stores == 1 then
        return openPanel(mine.stores[1].id)
    end
    -- several stores: pick through the county menu
    local items = {}
    for _, s in ipairs(mine.stores) do
        items[#items + 1] = {
            id = tostring(s.id),
            label = s.name,
            description = (s.code and (s.code .. ' · ') or '') .. s.role,
            rightText = s.status,
        }
    end
    Bridge.openMenu(
        { title = 'Your Stores', items = items },
        function(id) openPanel(tonumber(id)) end,
        function() end
    )
end)

function CloseManagement()
    if not mgmtOpen then return end
    mgmtOpen = false
    currentStore = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'mgmt:close' })
end

RegisterNUICallback('mgmtClose', function(_, cb)
    CloseManagement()
    cb({ ok = true })
end)

RegisterNUICallback('mgmtRefresh', function(_, cb)
    CreateThread(function()
        cb(await('sovereign_stores:mgmt:get', currentStore) or { ok = false, error = 'no_response' })
    end)
end)

RegisterNUICallback('mgmtAction', function(data, cb)
    CreateThread(function()
        cb(await('sovereign_stores:mgmt:action', currentStore, data.action, data.payload) or { ok = false, error = 'no_response' })
    end)
end)

RegisterNUICallback('mgmtFind', function(data, cb)
    CreateThread(function()
        cb(await('sovereign_stores:mgmt:findCharacter', data.query) or { ok = false, error = 'no_response' })
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and mgmtOpen then SetNuiFocus(false, false) end
end)
