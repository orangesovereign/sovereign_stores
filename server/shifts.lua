--[[=====================================================================
  SOVEREIGN STORES · SHIFTS & THE SHIFT DESK (features G1-G4, G6)

  The clock is server-authoritative: a heartbeat verifies every clocked
  worker is actually AT their store (Config.Presence radius) each tick;
  wander past the grace and the clock punches you out itself.

  Wages settle at clock-out from the operating ledger:
    hourly — rate × verified minutes / 60
    daily  — flat rate, needs Config.Wages.DailyMinMinutes verified
  A ledger that can't cover the wage logs an unpaid-wage event instead —
  stores never go into debt (design §E1).

  Owners and co-owners may clock in for presence (and the cashier swap)
  but draw no wage. While ANYONE is clocked in, the NPC cashier steps
  aside (placement republish with hidePed).
=====================================================================]]--

Shifts = {}

-- active[charid] = { storeId, src, clockIn = os.time(), verified = 0,
--                    missed = 0, row = timeclock id }
local active = {}

local function activeCountFor(storeId)
    local n = 0
    for _, sh in pairs(active) do
        if sh.storeId == storeId then n = n + 1 end
    end
    return n
end

function Shifts.activeCount(storeId) return activeCountFor(storeId) end

function Shifts.shiftOf(charid) return active[charid] end

---Everything the panel needs about the caller's shift.
function Shifts.view(charid, storeId)
    local sh = active[charid]
    if not sh or sh.storeId ~= storeId then return nil end
    local emp = nil
    for _, e in ipairs(PStores.staff(storeId)) do
        if e.charid == charid then emp = e end
    end
    local accrued = 0
    if emp then
        if emp.pay_model == 'hourly' then
            accrued = Util.round2((emp.pay_rate or 0) * sh.verified / 60)
        else
            accrued = (sh.verified >= (Config.Wages and Config.Wages.DailyMinMinutes or 120))
                and Util.round2(emp.pay_rate or 0) or 0
        end
    end
    return {
        clockIn = sh.clockIn, verified = sh.verified,
        accrued = accrued, payModel = emp and emp.pay_model or nil,
        onShift = true,
    }
end

---All clocked workers for a store (staff panel / overview).
function Shifts.roster(storeId)
    local out = {}
    for charid, sh in pairs(active) do
        if sh.storeId == storeId then
            out[#out + 1] = { charid = charid, clockIn = sh.clockIn, verified = sh.verified }
        end
    end
    return out
end

local function nearStore(src, s)
    local rc = s.register_coords
    if not rc then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local r = (Config.Presence and Config.Presence.RadiusMeters) or 25.0
    local dx, dy, dz = pos.x - rc.x, pos.y - rc.y, pos.z - rc.z
    return (dx * dx + dy * dy + dz * dz) <= (r * r)
end

function Shifts.clockIn(src, storeId)
    local charid = Bridge.getCharId(src)
    if not charid then return false, 'no_char' end
    if active[charid] then return false, 'already_clocked' end
    local s = PStores.get(storeId)
    if not s or not PStores.roleOf(storeId, charid) then return false, 'not_staff' end
    if not nearStore(src, s) then return false, 'not_at_store' end

    local row = Db.insert(
        'INSERT INTO sovereign_store_timeclock (store_id, charid, clock_in) VALUES (?, ?, NOW())',
        { storeId, charid })
    active[charid] = { storeId = storeId, src = src, clockIn = os.time(), verified = 0, missed = 0, row = row }
    EventLog.write(storeId, 'clock_in', charid, nil, nil)
    Npc.publishAll()   -- the NPC cashier steps aside
    return true
end

---Settle and close a shift. reason: 'self' | 'wandered' | 'dropped' | 'boot'
function Shifts.clockOut(charid, reason)
    local sh = active[charid]
    if not sh then return false, 'not_clocked' end
    active[charid] = nil

    local storeId = sh.storeId
    local emp = nil
    for _, e in ipairs(PStores.staff(storeId)) do
        if e.charid == charid then emp = e end
    end

    local wage = 0
    if emp and (emp.pay_rate or 0) > 0 then
        if emp.pay_model == 'daily' then
            local minMin = (Config.Wages and Config.Wages.DailyMinMinutes) or 120
            wage = (sh.verified >= minMin) and Util.round2(emp.pay_rate) or 0
        else
            wage = Util.round2(emp.pay_rate * sh.verified / 60)
        end
    end

    local paid = 0
    if wage > 0 then
        local okPay = Ledger.write(storeId, 'operating', 'wage', -wage, {
            actor = charid, note = ('%s · %d verified min · %s'):format(emp.pay_model, sh.verified, reason),
        })
        if okPay then
            paid = wage
            -- wages land in the worker's hand if they're online; owed via event log otherwise
            local src = Bridge.srcByCharId and Bridge.srcByCharId(charid) or nil
            if src then
                Bridge.money.add(src, wage)
                Bridge.notify(src, _U('wage_paid', wage))
            end
        else
            EventLog.write(storeId, 'wage_unpaid', charid, nil,
                { amount = wage, verified = sh.verified, reason = 'ledger_short' })
        end
    end

    Db.execute(
        'UPDATE sovereign_store_timeclock SET clock_out = NOW(), verified_minutes = ?, paid = ?, pay_amount = ? WHERE id = ?',
        { sh.verified, paid > 0 and 1 or 0, paid, sh.row })
    EventLog.write(storeId, 'clock_out', charid, nil, { verified = sh.verified, paid = paid, reason = reason })
    Npc.publishAll()   -- NPC cashier returns if the floor is empty
    return true, nil, paid
end

-- ── Presence heartbeat ──────────────────────────────────────────────

CreateThread(function()
    while true do
        local tick = (Config.Presence and Config.Presence.TickSeconds) or 60
        Wait(tick * 1000)
        for charid, sh in pairs(active) do
            local s = PStores.get(sh.storeId)
            local src = Bridge.srcByCharId and Bridge.srcByCharId(charid) or nil
            if not s then
                Shifts.clockOut(charid, 'boot')
            elseif not src then
                Shifts.clockOut(charid, 'dropped')
            elseif nearStore(src, s) then
                sh.src = src
                sh.missed = 0
                sh.verified = sh.verified + math.floor(tick / 60 + 0.5)
            else
                sh.missed = sh.missed + 1
                if sh.missed > ((Config.Presence and Config.Presence.GraceTicks) or 2) then
                    Shifts.clockOut(charid, 'wandered')
                    if src then Bridge.notify(src, _U('clocked_out_wandered')) end
                else
                    if src then Bridge.notify(src, _U('presence_warning')) end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local charid = Bridge.getCharId(src)
    if charid and active[charid] then Shifts.clockOut(charid, 'dropped') end
end)

-- Dangling shifts from a crash: close them at boot, unpaid but recorded.
CreateThread(function()
    Wait(4000)
    if Db.available() then
        Db.execute(
            "UPDATE sovereign_store_timeclock SET clock_out = clock_in, verified_minutes = 0, paid = 0 WHERE clock_out IS NULL",
            {})
    end
end)

-- ── The notes board (Shift Desk: notes + restock checklists, G4) ────

Notes = {}

function Notes.list(storeId)
    return Db.query(
        'SELECT id, charid, kind, content, checked, created_at FROM sovereign_store_notes WHERE store_id = ? ORDER BY checked, id DESC LIMIT 40',
        { storeId }) or {}
end

function Notes.add(storeId, charid, kind, content)
    content = tostring(content or ''):sub(1, 500)
    if #content < 2 then return false, 'bad_note' end
    kind = (kind == 'restock') and 'restock' or 'note'
    Db.insert('INSERT INTO sovereign_store_notes (store_id, charid, kind, content) VALUES (?, ?, ?, ?)',
        { storeId, charid, kind, content })
    return true
end

function Notes.toggle(storeId, noteId)
    local n = Db.execute('UPDATE sovereign_store_notes SET checked = 1 - checked WHERE id = ? AND store_id = ?',
        { noteId, storeId })
    return (n or 0) > 0
end

function Notes.remove(storeId, noteId, charid, isBoss)
    local n
    if isBoss then
        n = Db.execute('DELETE FROM sovereign_store_notes WHERE id = ? AND store_id = ?', { noteId, storeId })
    else
        n = Db.execute('DELETE FROM sovereign_store_notes WHERE id = ? AND store_id = ? AND charid = ?',
            { noteId, storeId, charid })
    end
    return (n or 0) > 0
end

-- ── Low stock (G6) ──────────────────────────────────────────────────

function Shifts.lowStock(storeId)
    return Db.query(
        [[SELECT item, quantity, low_threshold FROM sovereign_store_stock
          WHERE store_id = ? AND low_threshold IS NOT NULL AND quantity <= low_threshold
          ORDER BY quantity ASC]], { storeId }) or {}
end

Boot.shifts = true
