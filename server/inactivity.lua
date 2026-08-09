--[[=====================================================================
  SOVEREIGN STORES · INACTIVITY MONITOR (features F4, H6)

  A store standing dark for a season is a store the county can re-charter
  to someone who will open the doors. The clock reads characters.LastLogin
  — VORP stamps it on every character load (verified: vorp_core
  loadcharacter.lua:42), so it is the honest measure of an owner's absence.

    WarnDays      → one warning letter, once per absence
    RepossessDays → the county takes the keys

  A store is spared while inactivity_exempt_until is in the future (the
  Bureau's approved-absence override), and — if the county has enabled
  it — while a co-owner is still minding the place.

  "Once per absence" needs no new column: a warning is an event, and the
  event log already knows whether we wrote one since the owner's last
  login.
=====================================================================]]--

Inactivity = {}

local function lastLoginOf(charid)
    if not charid then return nil end
    return Db.scalar('SELECT LastLogin FROM characters WHERE charidentifier = ?', { charid })
end

---Days since a character last played, or nil if unknown.
local function daysAway(charid)
    if not charid then return nil end
    local d = Db.scalar('SELECT DATEDIFF(NOW(), LastLogin) FROM characters WHERE charidentifier = ?', { charid })
    return tonumber(d)
end

---The absence that counts for this store, honouring the co-owner rule.
local function effectiveDays(s)
    local days = daysAway(s.owner_charid)
    if (Config.Inactivity and Config.Inactivity.CoOwnerResets) and s.coowner_charid then
        local co = daysAway(s.coowner_charid)
        if co and (not days or co < days) then days = co end
    end
    return days
end

local function isExempt(s)
    if not s.inactivity_exempt_until then return false end
    return Db.scalar('SELECT 1 WHERE ? >= CURDATE()', { s.inactivity_exempt_until }) ~= nil
end

---Have we already warned since this owner last played?
local function alreadyWarned(s)
    return Db.scalar(
        [[SELECT 1 FROM sovereign_store_events e
          WHERE e.store_id = ? AND e.kind = 'inactivity_warned'
            AND e.created_at > COALESCE((SELECT LastLogin FROM characters WHERE charidentifier = ?), '1970-01-01')
          LIMIT 1]], { s.id, s.owner_charid }) ~= nil
end

---Dashboard view (H6): every owned store with its absence clock.
function Inactivity.report()
    local out = {}
    local warnDays = (Config.Inactivity and Config.Inactivity.WarnDays) or 30
    local seizeDays = (Config.Inactivity and Config.Inactivity.RepossessDays) or 45
    for id, s in pairs(PStores.all()) do
        if s.owner_charid and not PStores.isRetired(s) then
            local days = effectiveDays(s)
            if days and days >= warnDays then
                out[#out + 1] = {
                    id = id, name = s.name, code = s.code,
                    days = days,
                    daysLeft = math.max(0, seizeDays - days),
                    exempt = isExempt(s),
                    exemptUntil = s.inactivity_exempt_until,
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.days > b.days end)
    return out
end

function Inactivity.flagCount()
    return #Inactivity.report()
end

---One sweep. Exposed so an admin can force it.
function Inactivity.runCycle()
    local report = { warned = 0, seized = 0 }
    if not Db.available() then return report end

    local warnDays = (Config.Inactivity and Config.Inactivity.WarnDays) or 30
    local seizeDays = (Config.Inactivity and Config.Inactivity.RepossessDays) or 45

    for id, s in pairs(PStores.all()) do
        if s.owner_charid and not PStores.isRetired(s) and not isExempt(s) then
            local days = effectiveDays(s)
            if days then
                if days >= seizeDays then
                    local owner = s.owner_charid
                    local ok, swept = PStores.repossess(id, 'owner inactive', nil)
                    if ok then
                        report.seized = report.seized + 1
                        EventLog.write(id, 'inactivity_seizure', nil, owner, { days = days, swept = swept })
                        Webhooks.fire(id, 'repossession', {
                            title = _U('wh_repossessed'), color = 0x6D1F12,
                            fields = {
                                { name = _U('wh_store'), value = s.name },
                                { name = _U('wh_reason'), value = _U('wh_reason_inactive', days) },
                                { name = _U('wh_swept'), value = ('$%.2f'):format(swept or 0) },
                            },
                        })
                        Letters.send(owner, _U('letter_inactive_seized_subject'),
                            _U('letter_inactive_seized_body', s.name, days),
                            { storeId = id, notifyVariant = 'failed' })
                    end
                elseif days >= warnDays and not alreadyWarned(s) then
                    report.warned = report.warned + 1
                    EventLog.write(id, 'inactivity_warned', nil, s.owner_charid, { days = days })
                    Letters.send(s.owner_charid, _U('letter_inactive_warn_subject'),
                        _U('letter_inactive_warn_body', s.name, days, math.max(0, seizeDays - days)),
                        { storeId = id, notifyVariant = 'failed' })
                end
            end
        end
    end
    return report
end

CreateThread(function()
    Wait(45000)
    while true do
        if Db.available() then
            local ok, report = pcall(Inactivity.runCycle)
            if ok and report and (report.warned + report.seized) > 0 then
                Util.log(('inactivity: %d warned · %d seized'):format(report.warned, report.seized))
            end
        end
        Wait(((Config.Inactivity and Config.Inactivity.CheckMinutes) or 60) * 60000)
    end
end)

Boot.inactivity = true
