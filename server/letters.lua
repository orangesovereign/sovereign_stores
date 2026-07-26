--[[=====================================================================
  SOVEREIGN STORES · GOVERNMENT LETTERS (feature F3)

  The county writes to store owners: tax notices, delinquency warnings,
  repossession orders, inactivity warnings.

  sovereign_postoffice:SendMail is a documented STUB today (returns
  false,'not_implemented' until its Phase 3). So every letter is written
  to our own queue FIRST, then we attempt delivery:

    delivered  → row marked 'sent'
    stubbed    → row stays 'queued'; the owner still gets a Card notify
                 so nothing is silently lost

  A worker retries the queue periodically, so the day the post office
  opens its doors, every letter the county ever wrote gets delivered
  without anyone touching this file.
=====================================================================]]--

Letters = {}

local FLUSH_MINUTES <const> = 10

---Attempt real delivery. Returns true only on a confirmed send.
---The post office addresses mail by BOX NUMBER (verified contract), so a
---character with no box assigned yet simply has no address — the letter
---waits in our queue until they visit a post office.
local function deliver(row)
    if GetResourceState('sovereign_postoffice') ~= 'started' then return false, 'no_postoffice' end

    local okBox, box = pcall(function()
        return exports.sovereign_postoffice:GetBoxForCharacter(row.recipient_charid)
    end)
    if not okBox or not box then return false, 'no_box' end

    local ok, sent, err = pcall(function()
        return exports.sovereign_postoffice:SendMail({
            toBox      = box,
            fromBox    = nil,                   -- official sender, no reply
            fromName   = _U('letter_sender'),   -- required there; never defaulted
            subject    = row.subject,
            body       = row.body,
            stationery = row.stationery,
            notice     = true,                  -- County Notice
        })
    end)
    if not ok then return false, 'export_error' end
    -- SendMail returns ok:boolean, result:number|string
    if sent == true then return true end
    return false, tostring(err or 'not_implemented')
end

local function markSent(id)
    Db.execute("UPDATE sovereign_store_letters SET status = 'sent', sent_at = NOW() WHERE id = ?", { id })
end

---Write a letter and try to deliver it now.
---@param charid integer recipient character
---@param subject string
---@param body string
---@param opts table|nil { stationery, storeId, notifyVariant }
function Letters.send(charid, subject, body, opts)
    opts = opts or {}
    charid = tonumber(charid)
    if not charid then return false, 'no_recipient' end

    local id = Db.insert(
        [[INSERT INTO sovereign_store_letters (recipient_charid, subject, body, stationery)
          VALUES (?, ?, ?, ?)]],
        { charid, tostring(subject):sub(1, 120), tostring(body), opts.stationery or 'county_letterhead' })

    local row = { id = id, recipient_charid = charid, subject = subject, body = body,
                  stationery = opts.stationery or 'county_letterhead' }
    local ok = deliver(row)
    if ok and id then markSent(id) end

    -- Either way the owner hears about it if they're online.
    local src = Bridge.srcByCharId(charid)
    if src then
        Bridge.notifyCard(src, opts.notifyVariant or 'started', _U('letter_sender'), subject)
    end

    if opts.storeId then
        EventLog.write(opts.storeId, 'letter', nil, charid,
            { subject = subject, delivered = ok == true })
    end
    return true, ok == true and 'sent' or 'queued'
end

---Retry every queued letter. Safe to call any time.
function Letters.flush()
    local rows = Db.query(
        "SELECT id, recipient_charid, subject, body, stationery FROM sovereign_store_letters WHERE status = 'queued' ORDER BY id LIMIT 50", {})
    if not rows or #rows == 0 then return 0 end
    local sent = 0
    for _, row in ipairs(rows) do
        if deliver(row) then
            markSent(row.id)
            sent = sent + 1
        else
            break   -- still stubbed; stop hammering it this pass
        end
    end
    if sent > 0 then
        Util.ok(('letters: the post office took %d queued letter(s)'):format(sent))
    end
    return sent
end

function Letters.queuedCount()
    return tonumber(Db.scalar("SELECT COUNT(*) FROM sovereign_store_letters WHERE status = 'queued'", {})) or 0
end

CreateThread(function()
    Wait(20000)   -- let the post office boot first
    while true do
        if Db.available() then pcall(Letters.flush) end
        Wait(FLUSH_MINUTES * 60000)
    end
end)

Boot.letters = true
