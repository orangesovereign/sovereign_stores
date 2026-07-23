--[[=====================================================================
  SOVEREIGN STORES · SHARED UTIL
  Logging, locale lookup, money rounding. No external dependencies.
=====================================================================]]--

Util = {}

local RES <const> = GetCurrentResourceName()

function Util.log(msg)  print(('^6[%s]^7 %s'):format(RES, msg)) end
function Util.ok(msg)   print(('^2[%s]^7 %s'):format(RES, msg)) end
function Util.warn(msg) print(('^3[%s]^7 %s'):format(RES, msg)) end
function Util.err(msg)  print(('^1[%s]^7 %s'):format(RES, msg)) end
function Util.debug(msg) if Config.Debug then print(('^5[%s·debug]^7 %s'):format(RES, msg)) end end

-- money is always dollars with 2 decimals, half-up
function Util.round2(n)
    return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100
end

-- locale lookup with printf-style args; falls back to the key itself
function _U(key, ...)
    local locale = Locales and Locales[Config.Locale]
    local str = locale and locale[key]
    if not str then return key end
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, str, ...)
        return ok and formatted or str
    end
    return str
end
