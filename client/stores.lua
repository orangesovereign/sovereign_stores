--[[=====================================================================
  SOVEREIGN STORES · CLIENT — placements, blips, cashier peds, prompt
  Placements arrive via GlobalState (set server-side at boot; late
  joiners read it directly). Ped + prompt patterns follow vorp_stores'
  proven client code.
=====================================================================]]--

local placements = {}          -- runtime copies with handles
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local openPrompt = nil
local storefrontOpen = false

local SPAWN_DIST <const> = 25.0    -- ped appears/disappears around this
local PROMPT_KEY <const> = 0x760A9C6F  -- [G]

-- ── Prompt ──────────────────────────────────────────────────────────

local function setupPrompt()
    openPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(openPrompt, PROMPT_KEY)
    UiPromptSetText(openPrompt, VarString(10, 'LITERAL_STRING', _U('prompt_browse')))
    UiPromptSetEnabled(openPrompt, true)
    UiPromptSetVisible(openPrompt, true)
    UiPromptSetStandardMode(openPrompt, true)
    UiPromptSetGroup(openPrompt, promptGroup, 0)
    UiPromptRegisterEnd(openPrompt)
end

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
    local ped = CreatePed(model, p.coords.x, p.coords.y, p.coords.z - 1.0, p.heading, false, false, false, false)
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
                if d <= SPAWN_DIST and not p.pedHandle then
                    p.pedHandle = spawnPed(p)
                elseif d > SPAWN_DIST + 5.0 and p.pedHandle then
                    removePed(p)
                end

                -- prompt + open
                if d <= (Config.InteractDistance or 3.0) then
                    slept = false
                    UiPromptSetActiveGroupThisFrame(promptGroup, VarString(10, 'LITERAL_STRING', p.label), 0, 0, 0, 0)
                    if UiPromptHasStandardModeCompleted(openPrompt, 0) then
                        openStorefront(p.store)
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
end)
