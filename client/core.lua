--[[=====================================================================
  SOVEREIGN STORES · CLIENT CORE
  Phase 0: session-ready gate + debug confirmation. Feature files
  (storefront, prompts, blips, NPCs) arrive in Phase 1 and load before
  this file.
=====================================================================]]--

CreateThread(function()
    while not Bridge.ready() do Wait(500) end
    local ch = Bridge.character()
    Util.debug(('client ready — CharId=%s Job=%s'):format(
        tostring(ch and ch.CharId), tostring(ch and ch.Job)))
end)
