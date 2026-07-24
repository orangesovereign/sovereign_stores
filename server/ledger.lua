--[[=====================================================================
  SOVEREIGN STORES · STORE LEDGERS (design §4, feature E1/E2)
  Typed transactions with a running balance per (store, account).
  account: 'operating' (fluctuates by design) | 'tax' (deposit-only;
  only automated collection ever debits it — enforced by callers).
  Single writer path; balances cached in memory, seeded from the DB.
=====================================================================]]--

Ledger = {}

local balances = {}   -- ["store:account"] = number

local function keyOf(storeId, account) return storeId .. ':' .. account end

local function seed(storeId, account)
    local k = keyOf(storeId, account)
    if balances[k] == nil then
        local last = Db.scalar(
            'SELECT balance_after FROM sovereign_store_ledger WHERE store_id = ? AND account = ? ORDER BY id DESC LIMIT 1',
            { storeId, account })
        balances[k] = tonumber(last) or 0
    end
    return balances[k]
end

function Ledger.balance(storeId, account)
    return seed(storeId, account or 'operating')
end

---Write one typed transaction. amount is SIGNED (+credit / -debit).
---Refuses debits that would overdraw (stores never carry debt, design §7.2).
---@return boolean ok, number balanceAfter
function Ledger.write(storeId, account, kind, amount, opts)
    opts = opts or {}
    amount = Util.round2(amount)
    if amount == 0 then return false, seed(storeId, account) end

    local k = keyOf(storeId, account)
    local current = seed(storeId, account)
    local after = Util.round2(current + amount)
    if after < 0 then return false, current end

    balances[k] = after
    Db.insert(
        [[INSERT INTO sovereign_store_ledger
          (store_id, account, type, amount, balance_after, actor_charid, item, qty, note)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { storeId, account, kind, amount, after, opts.actor, opts.item, opts.qty, opts.note }
    )
    return true, after
end

function Ledger.history(storeId, account, limit)
    return Db.query(
        [[SELECT type, amount, balance_after, actor_charid, item, qty, note, created_at
          FROM sovereign_store_ledger WHERE store_id = ? AND account = ?
          ORDER BY id DESC LIMIT ?]],
        { storeId, account, math.min(tonumber(limit) or 50, 200) }
    ) or {}
end

-- Sweep both ledgers into the government fund (repossession, design §5).
function Ledger.sweepToFund(storeId, reason)
    local swept = 0
    for _, account in ipairs({ 'operating', 'tax' }) do
        local bal = seed(storeId, account)
        if bal > 0 then
            local ok = Ledger.write(storeId, account, 'sweep', -bal, { note = reason })
            if ok then
                Fund.credit('repossession_sweep', bal, storeId, reason)
                swept = Util.round2(swept + bal)
            end
        end
    end
    return swept
end
