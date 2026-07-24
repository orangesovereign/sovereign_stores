--[[=====================================================================
  SOVEREIGN STORES · CLIENT — placements, blips, cashier peds, prompt
  Placements arrive via GlobalState (set server-side at boot; late
  joiners read it directly). Ped + prompt patterns follow vorp_stores'
  proven client code.
=====================================================================]]--

local placements = {}          -- runtime copies with handles
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local openPrompt = nil
local managePrompt = nil
local storefrontOpen = false
local myStores = {}            -- set of store ids this character staffs

local SPAWN_DIST <const> = 25.0    -- ped appears/disappears around this
local PROMPT_KEY <const> = 0x760A9C6F   -- [G]  (INPUT_WHISTLE — stables-proven)
local MANAGE_KEY <const> = 0x3B24C470   -- [F]  INPUT_CONTEXT_B (rdr3_discoveries Controls)

-- ── Prompts ─────────────────────────────────────────────────────────

local function setupPrompt()
    openPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(openPrompt, PROMPT_KEY)
    UiPromptSetText(openPrompt, VarString(10, 'LITERAL_STRING', _U('prompt_browse')))
    UiPromptSetEnabled(openPrompt, true)
    UiPromptSetVisible(openPrompt, true)
    UiPromptSetStandardMode(openPrompt, true)
    UiPromptSetGroup(openPrompt, promptGroup, 0)
    UiPromptRegisterEnd(openPrompt)

    -- staff-only second prompt at the same counter; visibility toggled per frame
    managePrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(managePrompt, MANAGE_KEY)
    UiPromptSetText(managePrompt, VarString(10, 'LITERAL_STRING', _U('prompt_manage')))
    UiPromptSetEnabled(managePrompt, false)
    UiPromptSetVisible(managePrompt, false)
    UiPromptSetStandardMode(managePrompt, true)
    UiPromptSetGroup(managePrompt, promptGroup, 0)
    UiPromptRegisterEnd(managePrompt)
end

-- ── Staffed-store cache (drives the Manage prompt) ──────────────────

local function refreshMyStores()
    local Core = exports.vorp_core:GetCore()
    local res = Core.Callback.TriggerAwait('sovereign_stores:mgmt:myStores')
    myStores = {}
    if res and res.ok then
        for _, s in ipairs(res.stores) do myStores[tonumber(s.id)] = true end
    end
end

RegisterNetEvent('sovereign_stores:rosterChanged', function()
    CreateThread(refreshMyStores)
end)

-- ── Blips / peds per placement ──────────────────────────────────────

local function addBlip(p)
    if not p.blip then return nil end
    local blip = BlipAddForCoords(1664425300, p.coords.x, p.coords.y, p.coords.z)
    SetBlipSprite(blip, p.blip.sprite, false)
    BlipAddModifier(blip, joaat('BLIP_MODIFIER_MP_COLOR_32'))
    SetBlipName(blip, p.blip.label or p.label)
    return blip
end

local function spawnPed(p)
    local model = joaat(p.npcModel)
    RequestModel(model, false)
    local tries = 0
    while not HasModelLoaded(model) and tries < 100 do Wait(50) tries = tries + 1 end
    if not HasModelLoaded(model) then
        Util.warn(('ped model %s never loaded'):format(p.npcModel))
        return nil
    end
    -- Ground-snap before freezing. Chartered stores capture the admin's
    -- GetEntityCoords (≈1m above the floor), so without this the cashier
    -- floats (owner report 2026-07-24); config coords pass through ≈unchanged.
    -- Query from +2.0, the pattern proven in coal_stables. Falls back to the
    -- configured Z if collision isn't streamed yet.
    local z = p.coords.z
    for _ = 1, 5 do
        local found, groundZ = GetGroundZAndNormalFor_3dCoord(p.coords.x, p.coords.y, p.coords.z + 2.0)
        if found and groundZ then z = groundZ break end
        Wait(100)
    end
    local ped = CreatePed(model, p.coords.x, p.coords.y, z, p.heading, false, false, false, false)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetModelAsNoLongerNeeded(model)
    return ped
end

local function removePed(p)
    if p.pedHandle and DoesEntityExist(p.pedHandle) then DeleteEntity(p.pedHandle) end
    p.pedHandle = nil
end

-- ── Placement sync ──────────────────────────────────────────────────

local function rebuildPlacements(raw)
    for _, p in ipairs(placements) do
        removePed(p)
        if p.blipHandle then RemoveBlip(p.blipHandle) end
    end
    placements = {}
    for _, src in ipairs(raw or {}) do
        local p = {
            store = src.store, idx = src.idx, label = src.label,
            coords = src.coords, heading = src.heading,
            npcModel = src.npcModel, blip = src.blip,
            hidePed = src.hidePed == true,   -- staff clocked in: no NPC cashier (G3)
            playerStoreId = tonumber(tostring(src.store):match('^p:(%d+)$')),
            pedHandle = nil, blipHandle = nil,
        }
        p.blipHandle = addBlip(p)
        placements[#placements + 1] = p
    end
    Util.debug(('placements loaded: %d'):format(#placements))
end

CreateThread(function()
    while not Bridge.ready() do Wait(500) end
    setupPrompt()
    refreshMyStores()
    -- initial read + live updates
    while GlobalState['sovereign_stores:placements'] == nil do Wait(500) end
    rebuildPlacements(GlobalState['sovereign_stores:placements'])
    AddStateBagChangeHandler('sovereign_stores:placements', 'global', function(_, _, value)
        rebuildPlacements(value)
    end)
end)

-- ── Main proximity loop ─────────────────────────────────────────────

local function openStorefront(storeKey)
    if storefrontOpen then return end
    local Core = exports.vorp_core:GetCore()
    local res = Core.Callback.TriggerAwait('sovereign_stores:getStore', storeKey)
    if not res or not res.ok then
        Bridge.notify(_U('store_err_' .. tostring(res and res.error or 'unknown')))
        return
    end
    storefrontOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'store:open', payload = res })
end

function CloseStorefront()
    if not storefrontOpen then return end
    storefrontOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'store:close' })
end

CreateThread(function()
    while true do
        local slept = true
        if #placements > 0 and not storefrontOpen then
            local pos = GetEntityCoords(PlayerPedId())
            for _, p in ipairs(placements) do
                local d = #(pos - vector3(p.coords.x, p.coords.y, p.coords.z))

                -- ped lifecycle
                if d <= SPAWN_DIST and not p.pedHandle and not p.hidePed then
                    p.pedHandle = spawnPed(p)
                elseif p.pedHandle and (d > SPAWN_DIST + 5.0 or p.hidePed) then
                    removePed(p)
                end

                -- prompt + open
                if d <= (Config.InteractDistance or 3.0) then
                    slept = false
                    local staffHere = p.playerStoreId ~= nil and myStores[p.playerStoreId] == true
                    UiPromptSetVisible(managePrompt, staffHere)
                    UiPromptSetEnabled(managePrompt, staffHere)
                    UiPromptSetActiveGroupThisFrame(promptGroup, VarString(10, 'LITERAL_STRING', p.label), 0, 0, 0, 0)
                    if UiPromptHasStandardModeCompleted(openPrompt, 0) then
                        openStorefront(p.store)
                    elseif staffHere and UiPromptHasStandardModeCompleted(managePrompt, 0) then
                        TriggerServerEvent('sovereign_stores:requestManagement', p.playerStoreId)
                    end
                end
            end
        end
        Wait(slept and 500 or 0)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, p in ipairs(placements) do
        removePed(p)
        if p.blipHandle then RemoveBlip(p.blipHandle) end
    end
    if storefrontOpen then SetNuiFocus(false, false) end
    if openPrompt then UiPromptDelete(openPrompt) end
    if managePrompt then UiPromptDelete(managePrompt) end
end)
