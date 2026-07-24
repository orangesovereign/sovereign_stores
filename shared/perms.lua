--[[=====================================================================
  SOVEREIGN STORES · PERMISSION FLAGS (design §3.2, feature D2)
  Stored as a bitfield on sovereign_store_employees.permissions.
  Owner and co-owner implicitly hold ALL flags; these gate employees.
=====================================================================]]--

Perms = {
    STOCK          = 1,   -- add/remove stock, fulfill restocks, buy-order intake
    FUNDS_DEPOSIT  = 2,   -- deposit into operating + tax ledgers
    FUNDS_WITHDRAW = 4,   -- withdraw from operating ledger
    PRICES         = 8,   -- set prices, create/end sales
    STOREFRONT     = 16,  -- name, blip label, branding, open/close
}
Perms.ALL = Perms.STOCK | Perms.FUNDS_DEPOSIT | Perms.FUNDS_WITHDRAW | Perms.PRICES | Perms.STOREFRONT

Perms.LABELS = {
    [Perms.STOCK]          = 'Stock',
    [Perms.FUNDS_DEPOSIT]  = 'Deposit Funds',
    [Perms.FUNDS_WITHDRAW] = 'Withdraw Funds',
    [Perms.PRICES]         = 'Prices & Sales',
    [Perms.STOREFRONT]     = 'Storefront',
}

function Perms.has(mask, flag)
    return ((tonumber(mask) or 0) & flag) ~= 0
end

-- sanitize an arbitrary number down to known flags
function Perms.clean(mask)
    return (tonumber(mask) or 0) & Perms.ALL
end

function Perms.list(mask)
    local out = {}
    for _, flag in ipairs({ Perms.STOCK, Perms.FUNDS_DEPOSIT, Perms.FUNDS_WITHDRAW, Perms.PRICES, Perms.STOREFRONT }) do
        if Perms.has(mask, flag) then out[#out + 1] = Perms.LABELS[flag] end
    end
    return out
end
