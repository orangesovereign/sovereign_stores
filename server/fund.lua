--[[=====================================================================
  SOVEREIGN STORES · GOVERNMENT FUND (design §4.3, features B9/E3)
  Single county-wide balance. Every movement is a typed row in
  sovereign_government_fund with a running balance_after. Exposed via
  exports so a future treasury script can read and spend it.
=====================================================================]]--

Fund = {}

local balance = nil   -- cached; loaded at boot, maintained on every write

function Fund.load()
    local last = Db.scalar('SELECT balance_after FROM sovereign_government_fund ORDER BY id DESC LIMIT 1', {})
    balance = tonumber(last) or 0
    Util.debug(('government fund balance: $%.2f'):format(balance))
    return balance
end

function Fund.balance()
    if balance == nil then Fund.load() end
    return balance
end

-- amount is always positive; kind decides the sign written to the row.
local function write(kind, signedAmount, refStoreId, note)
    if balance == nil then Fund.load() end
    balance = Util.round2(balance + signedAmount)
    Db.insert(
        'INSERT INTO sovereign_government_fund (type, amount, balance_after, ref_store_id, note) VALUES (?, ?, ?, ?, ?)',
        { kind, Util.round2(signedAmount), balance, refStoreId, note }
    )
    return balance
end

-- Money INTO the fund (npc_sale, tax, repossession_sweep)
function Fund.credit(kind, amount, refStoreId, note)
    amount = Util.round2(amount)
    if amount <= 0 then return balance end
    return write(kind, amount, refStoreId, note)
end

-- Money OUT of the fund (npc_purchase = NPC store buying from a player, spend)
function Fund.debit(kind, amount, refStoreId, note)
    amount = Util.round2(amount)
    if amount <= 0 then return balance end
    return write(kind, -amount, refStoreId, note)
end

-- ── Integration surface (feature E3) ────────────────────────────────
exports('GetGovernmentFund', function()
    return Fund.balance()
end)

-- Spend by another script (future treasury). Refuses overdraft.
exports('SpendGovernmentFund', function(amount, note)
    amount = Util.round2(tonumber(amount) or 0)
    if amount <= 0 then return false, 'bad_amount' end
    if Fund.balance() < amount then return false, 'insufficient' end
    Fund.debit('spend', amount, nil, note or 'external spend')
    return true, Fund.balance()
end)
