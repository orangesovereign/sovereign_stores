--[[=====================================================================
  SOVEREIGN STORES · CLIENT — Commerce Bureau bridge
  Opens on the server-gated /storeadmin command; every data request is
  re-authorized server-side. "Use my position" resolves here.
=====================================================================]]--

local adminOpen = false

local function await(name, ...)
    local Core = exports.vorp_core:GetCore()
    return Core.Callback.TriggerAwait(name, ...)
end

RegisterNetEvent('sovereign_stores:openAdmin', function()
    if adminOpen then return end
    local res = await('sovereign_stores:admin:overview')
    if not res or not res.ok then return end
    adminOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'admin:open', payload = res })
end)

function CloseAdmin()
    if not adminOpen then return end
    adminOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'admin:close' })
end

RegisterNUICallback('adminClose', function(_, cb)
    CloseAdmin()
    cb({ ok = true })
end)

local FORWARD = {
    adminOverview = { 'sovereign_stores:admin:overview' },
    adminFund     = { 'sovereign_stores:admin:fund' },
    adminEvents   = { 'sovereign_stores:admin:events' },
}

for nuiName, def in pairs(FORWARD) do
    RegisterNUICallback(nuiName, function(_, cb)
        CreateThread(function()
            cb(await(def[1]) or { ok = false, error = 'no_response' })
        end)
    end)
end

RegisterNUICallback('adminStore', function(data, cb)
    CreateThread(function()
        cb(await('sovereign_stores:admin:store', data.id) or { ok = false, error = 'no_response' })
    end)
end)

RegisterNUICallback('adminAction', function(data, cb)
    CreateThread(function()
        cb(await('sovereign_stores:admin:action', data.id, data.action, data.payload) or { ok = false, error = 'no_response' })
    end)
end)

RegisterNUICallback('adminFind', function(data, cb)
    CreateThread(function()
        cb(await('sovereign_stores:admin:findCharacter', data.query) or { ok = false, error = 'no_response' })
    end)
end)

RegisterNUICallback('adminCreate', function(data, cb)
    CreateThread(function()
        if data.useMyPosition then
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            data.coords = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) }
        end
        data.useMyPosition = nil
        cb(await('sovereign_stores:admin:create', data) or { ok = false, error = 'no_response' })
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and adminOpen then SetNuiFocus(false, false) end
end)
