--[[=====================================================================
  SOVEREIGN STORES · CONFIG VALIDATION
  Validate.run() returns an array of human-readable problems (empty = green).
  Called at boot by server/core.lua and echoed by /stores_diag.
=====================================================================]]--

Validate = {}

function Validate.run()
    local problems = {}
    local function bad(msg) problems[#problems + 1] = msg end

    if type(Config) ~= 'table' then
        return { 'Config table missing entirely — config/config.lua failed to load' }
    end

    if type(Config.Locale) ~= 'string' or not (Locales and Locales[Config.Locale]) then
        bad(('Config.Locale "%s" has no matching file in config/locales/'):format(tostring(Config.Locale)))
    end

    if type(Config.AdminGroups) ~= 'table' or #Config.AdminGroups == 0 then
        bad('Config.AdminGroups must be a non-empty list (e.g. { "admin" })')
    end
    if type(Config.AdminAce) ~= 'string' or Config.AdminAce == '' then
        bad('Config.AdminAce must be a non-empty ace string')
    end

    if type(Config.MaxEmployees) ~= 'number' or Config.MaxEmployees < 0 then
        bad('Config.MaxEmployees must be a number >= 0')
    end
    if type(Config.MaxCoOwners) ~= 'number' or Config.MaxCoOwners < 0 then
        bad('Config.MaxCoOwners must be a number >= 0')
    end

    if type(Config.StorageIdPrefix) ~= 'string' or Config.StorageIdPrefix == '' then
        bad('Config.StorageIdPrefix must be a non-empty string')
    end
    if type(Config.StorageSlots) ~= 'number' or Config.StorageSlots < 1 then
        bad('Config.StorageSlots must be a number >= 1')
    end

    for _, section in ipairs({ 'Tax', 'Inactivity', 'Presence' }) do
        if type(Config[section]) ~= 'table' then
            bad(('Config.%s section missing'):format(section))
        end
    end

    return problems
end
