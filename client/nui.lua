--[[=====================================================================
  SOVEREIGN STORES · CLIENT — NUI callbacks
  The UI talks only to these; these talk only to server callbacks.
  Responses ride the NUI callback reply (postoffice pattern).
=====================================================================]]--

local function await(name, ...)
    local Core = exports.vorp_core:GetCore()
    return Core.Callback.TriggerAwait(name, ...)
end

RegisterNUICallback('close', function(_, cb)
    CloseStorefront()
    cb({ ok = true })
end)

RegisterNUICallback('checkout', function(data, cb)
    CreateThread(function()
        local res = await('sovereign_stores:checkout', data.store, data.cart)
        cb(res or { ok = false, error = 'no_response' })
    end)
end)

RegisterNUICallback('sell', function(data, cb)
    CreateThread(function()
        local res = await('sovereign_stores:sell', data.store, data.entries)
        cb(res or { ok = false, error = 'no_response' })
    end)
end)

-- fresh catalog + sellable view (after a sale changes the inventory)
RegisterNUICallback('refresh', function(data, cb)
    CreateThread(function()
        local res = await('sovereign_stores:getStore', data.store)
        cb(res or { ok = false, error = 'no_response' })
    end)
end)
