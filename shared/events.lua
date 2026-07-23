--[[=====================================================================
  SOVEREIGN STORES · EVENT REGISTRY
  Every net event name lives here — no string literals at call sites.
  Grows phase by phase; keep server-bound and client-bound separated.
=====================================================================]]--

Events = {
    prefix = 'sovereign_stores:',

    -- server-bound (client → server)
    RequestDiag = 'sovereign_stores:requestDiag',

    -- client-bound (server → client)
    DiagResult  = 'sovereign_stores:diagResult',
}
