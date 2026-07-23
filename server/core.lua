--[[=====================================================================
  SOVEREIGN STORES · SERVER CORE
  Boot health report, /stores_diag, isBooted export.
  Pattern follows the house convention (stables/medical/postoffice).
=====================================================================]]--

local booted, bootOk = false, false
local VERSION <const> = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?'

local function buildReport()
    local report = {
        version   = VERSION,
        config    = Validate.run(),          -- array of problems (empty = green)
        deps      = Bridge.checkDependencies(),
        oxmysql   = Db.available(),
        dbMissing = Db.available() and Db.verifySchema() or Db.requiredTables(),
        counts    = {},
    }
    if report.oxmysql and #report.dbMissing == 0 then
        report.counts.stores = tonumber(Db.scalar('SELECT COUNT(*) FROM sovereign_stores', {})) or 0
    end
    report.ok = (#report.config == 0) and report.oxmysql and (#report.dbMissing == 0)
    for _, dep in ipairs(report.deps) do
        if dep.required and dep.state ~= 'started' then report.ok = false end
    end
    return report
end

local function printReport(report)
    Util.log(('═══ %s v%s ═══'):format(_U('diag_header'), report.version))

    Util.log(_U('diag_config') .. ':')
    if #report.config == 0 then Util.ok('  ' .. _U('diag_ok'))
    else for _, p in ipairs(report.config) do Util.err('  ' .. p) end end

    Util.log(_U('diag_deps') .. ':')
    for _, dep in ipairs(report.deps) do
        local line = ('  %-22s %s%s'):format(dep.name, dep.state, dep.required and '' or ' (optional)')
        if dep.state == 'started' then Util.ok(line)
        elseif dep.required then Util.err(line)
        else Util.warn(line) end
    end

    Util.log(_U('diag_schema') .. ':')
    if not report.oxmysql then
        Util.err('  oxmysql not started — no database access')
    elseif #report.dbMissing == 0 then
        Util.ok(('  %s (%d stores)'):format(_U('diag_ok'), report.counts.stores or 0))
    else
        for _, tbl in ipairs(report.dbMissing) do
            Util.err(('  %s: %s — run sql/install.sql'):format(_U('diag_missing'), tbl))
        end
    end

    if report.ok then Util.ok(_U('boot_ok', report.version))
    else Util.err(_U('boot_problems')) end
end

CreateThread(function()
    Wait(1500) -- let dependencies finish their own boots
    local report = buildReport()
    printReport(report)
    booted, bootOk = true, report.ok
end)

exports('isBooted', function() return booted and bootOk end)

RegisterCommand('stores_diag', function(source)
    if source ~= 0 and not Bridge.isAdmin(source) then
        return Bridge.notify(source, _U('err_no_permission'))
    end
    local report = buildReport()
    printReport(report)
    if source ~= 0 then
        Bridge.notifyCard(source, report.ok and 'complete' or 'failed', _U('diag_header'),
            report.ok and _U('diag_notify_ok') or _U('diag_notify_bad'))
    end
end, false)
