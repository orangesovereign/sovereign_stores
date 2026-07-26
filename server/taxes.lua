--[[=====================================================================
  SOVEREIGN STORES · PROPERTY TAX (features F1, F2, E2)

  Every owned player store owes a monthly property tax: a percentage of
  the price the Bureau recorded when it was chartered.

  The cycle lives in the DATABASE (tax_due_date), never in a timer, so a
  restart mid-month changes nothing — the collector simply sweeps for
  whatever is due now and catches up.

  Collection order (both purses are the store's own money):
    1. the tax reserve — what a careful owner set aside
    2. the operating ledger — the shortfall, if config allows

  Failure opens the delinquency clock: a letter goes out, the store is
  marked delinquent, and after Config.Tax.GraceHours the county tries
  once more. Still short → the store is repossessed, its ledgers swept
  to the treasury, its roster cleared.
=====================================================================]]--

Taxes = {}

local function dueAmount(s)
    return Util.round2((tonumber(s.purchase_price) or 0) * (tonumber(s.tax_rate) or 0) / 100)
end

---Owner-facing money summary used by the panel and the Bureau.
function Taxes.quote(s)
    return {
        amount   = dueAmount(s),
        dueDate  = s.tax_due_date,
        state    = s.tax_state,
        reserve  = Ledger.balance(s.id, 'tax'),
        since    = s.delinquent_since,
    }
end

---Start (or restart) the clock for a store — called when an owner is
---assigned, or when a rate/price first makes tax meaningful.
function Taxes.startCycle(storeId)
    local s = PStores.get(storeId)
    if not s or not s.owner_charid then return false end
    if s.tax_due_date then return false end            -- already ticking
    if dueAmount(s) <= 0 then return false end         -- nothing owed: no clock
    local period = (Config.Tax and Config.Tax.PeriodDays) or 30
    Db.execute('UPDATE sovereign_stores SET tax_due_date = DATE_ADD(CURDATE(), INTERVAL ? DAY) WHERE id = ?',
        { period, storeId })
    PStores.refresh(storeId)
    return true
end

---Attempt one collection. Returns collected:boolean, amount:number.
local function collect(s)
    local amount = dueAmount(s)
    if amount <= 0 then return true, 0 end

    local reserve = Ledger.balance(s.id, 'tax')
    local fromReserve = math.min(reserve, amount)
    local shortfall = Util.round2(amount - fromReserve)

    if shortfall > 0 then
        if not (Config.Tax and Config.Tax.UseOperatingShortfall) then return false, amount end
        if Ledger.balance(s.id, 'operating') < shortfall then return false, amount end
    end

    -- take the reserve portion, then the shortfall, then credit the county
    if fromReserve > 0 then
        Ledger.write(s.id, 'tax', 'tax_collected', -fromReserve,
            { note = ('property tax %s'):format(tostring(s.tax_due_date)) })
    end
    if shortfall > 0 then
        Ledger.write(s.id, 'operating', 'tax_collected', -shortfall,
            { note = ('property tax shortfall %s'):format(tostring(s.tax_due_date)) })
    end
    Fund.credit('tax', amount, s.id, ('%s (%s)'):format(s.name, s.code or '—'))
    return true, amount
end

local function nextDue()
    local period = (Config.Tax and Config.Tax.PeriodDays) or 30
    return period
end

local function onPaid(s, amount)
    Db.execute(
        [[UPDATE sovereign_stores SET tax_due_date = DATE_ADD(CURDATE(), INTERVAL ? DAY),
          tax_state = 'current', delinquent_since = NULL WHERE id = ?]], { nextDue(), s.id })
    -- refresh returns the NEW cache row; `s` still holds the old due date
    local fresh = PStores.refresh(s.id) or s
    EventLog.write(s.id, 'tax_paid', nil, nil, { amount = amount })
    Webhooks.fire(s.id, 'tax', {
        title = _U('wh_tax_paid'), color = 0x7D8D5C,
        fields = { { name = _U('wh_store'), value = s.name }, { name = _U('wh_amount'), value = ('$%.2f'):format(amount) } },
    })
    if s.owner_charid then
        Letters.send(s.owner_charid, _U('letter_tax_receipt_subject'),
            _U('letter_tax_receipt_body', s.name, amount, tostring(fresh.tax_due_date)),
            { storeId = s.id, notifyVariant = 'complete' })
    end
end

local function onDelinquent(s, amount)
    Db.execute(
        [[UPDATE sovereign_stores SET tax_state = 'delinquent', delinquent_since = NOW() WHERE id = ?]],
        { s.id })
    PStores.refresh(s.id)
    EventLog.write(s.id, 'tax_delinquent', nil, nil, { amount = amount })
    Webhooks.fire(s.id, 'tax', {
        title = _U('wh_tax_delinquent'), color = 0xA03322,
        fields = {
            { name = _U('wh_store'), value = s.name },
            { name = _U('wh_amount'), value = ('$%.2f'):format(amount) },
            { name = _U('wh_deadline'), value = ('%d h'):format((Config.Tax and Config.Tax.GraceHours) or 72) },
        },
    })
    if s.owner_charid then
        Letters.send(s.owner_charid, _U('letter_delinquent_subject'),
            _U('letter_delinquent_body', s.name, amount, (Config.Tax and Config.Tax.GraceHours) or 72),
            { storeId = s.id, notifyVariant = 'failed' })
    end
end

local function onSeized(s, amount)
    -- capture the owner BEFORE repossession clears it from the cache row
    local owner, name = s.owner_charid, s.name
    local ok, swept = PStores.repossess(s.id, 'unpaid property tax', nil)
    EventLog.write(s.id, 'tax_seizure', nil, owner, { amount = amount, swept = swept })
    Webhooks.fire(s.id, 'repossession', {
        title = _U('wh_repossessed'), color = 0x6D1F12,
        fields = {
            { name = _U('wh_store'), value = name },
            { name = _U('wh_reason'), value = _U('wh_reason_tax') },
            { name = _U('wh_swept'), value = ('$%.2f'):format(swept or 0) },
        },
    })
    if owner then
        -- body reads "(amount) … repossessed (name)" — order matters
        Letters.send(owner, _U('letter_seized_subject'),
            _U('letter_seized_body', amount, name), { storeId = s.id, notifyVariant = 'failed' })
    end
    return ok
end

---One sweep of everything due. Exposed so /stores_tax can force it.
---@return table report { checked, paid, delinquent, seized }
function Taxes.runCycle()
    local report = { checked = 0, paid = 0, delinquent = 0, seized = 0 }
    if not Db.available() then return report end

    local grace = (Config.Tax and Config.Tax.GraceHours) or 72

    for id, s in pairs(PStores.all()) do
        if s.owner_charid and s.status ~= 'repossessed' and dueAmount(s) > 0 then
            -- 1) delinquent stores whose grace has run out
            if s.tax_state == 'delinquent' then
                local expired = Db.scalar(
                    'SELECT 1 FROM sovereign_stores WHERE id = ? AND delinquent_since IS NOT NULL AND delinquent_since <= DATE_SUB(NOW(), INTERVAL ? HOUR)',
                    { id, grace })
                if expired then
                    report.checked = report.checked + 1
                    local paid, amount = collect(s)
                    if paid then
                        onPaid(s, amount)
                        report.paid = report.paid + 1
                    else
                        onSeized(s, amount)
                        report.seized = report.seized + 1
                    end
                end

            -- 2) stores whose due date has arrived
            elseif s.tax_due_date then
                local due = Db.scalar('SELECT 1 FROM sovereign_stores WHERE id = ? AND tax_due_date <= CURDATE()', { id })
                if due then
                    report.checked = report.checked + 1
                    local paid, amount = collect(s)
                    if paid then
                        onPaid(s, amount)
                        report.paid = report.paid + 1
                    else
                        onDelinquent(s, amount)
                        report.delinquent = report.delinquent + 1
                    end
                end

            -- 3) owned, taxable, but never started (assigned before tax mattered)
            else
                Taxes.startCycle(id)
            end
        end
    end
    return report
end

CreateThread(function()
    Wait(30000)   -- after boot settles
    while true do
        if Db.available() then
            local ok, report = pcall(Taxes.runCycle)
            if ok and report and (report.paid + report.delinquent + report.seized) > 0 then
                Util.log(('taxes: %d paid · %d delinquent · %d seized'):format(
                    report.paid, report.delinquent, report.seized))
            end
        end
        Wait(((Config.Tax and Config.Tax.CheckMinutes) or 15) * 60000)
    end
end)

Boot.taxes = true
