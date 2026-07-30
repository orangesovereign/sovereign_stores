--[[=====================================================================
  SOVEREIGN STORES · DB LAYER
  oxmysql wrappers + schema verification. This resource owns every
  sovereign_store* table plus sovereign_weapon_serials and
  sovereign_government_fund. No auto-migrations: sql/install.sql is run
  by the operator; boot only VERIFIES and fails loudly.
=====================================================================]]--

Db = {}

local REQUIRED_TABLES <const> = {
    'sovereign_stores',
    'sovereign_store_locations',
    'sovereign_store_employees',
    'sovereign_store_stock',
    'sovereign_store_buy_orders',
    'sovereign_store_ledger',
    'sovereign_store_timeclock',
    'sovereign_store_notes',
    'sovereign_store_letters',
    'sovereign_store_events',
    'sovereign_weapon_serials',
    'sovereign_government_fund',
    'sovereign_store_sale_items',
}

function Db.available()
    return GetResourceState('oxmysql') == 'started' and MySQL ~= nil
end

-- thin await wrappers so feature code reads cleanly and errors are tagged
function Db.query(sql, params)
    local ok, res = pcall(function() return MySQL.query.await(sql, params or {}) end)
    if not ok then Util.err('Db.query failed: ' .. tostring(res) .. ' — ' .. sql) return nil end
    return res
end

function Db.scalar(sql, params)
    local ok, res = pcall(function() return MySQL.scalar.await(sql, params or {}) end)
    if not ok then Util.err('Db.scalar failed: ' .. tostring(res) .. ' — ' .. sql) return nil end
    return res
end

function Db.execute(sql, params)
    local ok, res = pcall(function() return MySQL.update.await(sql, params or {}) end)
    if not ok then Util.err('Db.execute failed: ' .. tostring(res) .. ' — ' .. sql) return nil end
    return res
end

function Db.insert(sql, params)
    local ok, res = pcall(function() return MySQL.insert.await(sql, params or {}) end)
    if not ok then Util.err('Db.insert failed: ' .. tostring(res) .. ' — ' .. sql) return nil end
    return res
end

-- Insert where failure is an expected outcome (unique-constraint retry
-- loops, e.g. weapon serials): no error spam, returns ok, result/err.
function Db.tryInsert(sql, params)
    local ok, res = pcall(function() return MySQL.insert.await(sql, params or {}) end)
    if not ok then return false, res end
    return true, res
end

-- returns array of missing table names (empty = schema green)
function Db.verifySchema()
    local missing = {}
    if not Db.available() then return REQUIRED_TABLES end
    for _, tbl in ipairs(REQUIRED_TABLES) do
        local found = Db.scalar('SHOW TABLES LIKE ?', { tbl })
        if not found then missing[#missing + 1] = tbl end
    end
    return missing
end

function Db.requiredTables()
    return REQUIRED_TABLES
end

-- Columns added by dated upgrade blocks: verified at boot so a migration
-- that silently failed (engine syntax differences — ledger Phase 3 D2)
-- names itself instead of erroring at first use.
local REQUIRED_COLUMNS <const> = {
    { table = 'sovereign_store_stock', column = 'low_threshold', fix = 'sql/upgrades.sql · 2026-07-24b' },
}

---returns array of { table, column, fix } for columns that are missing
function Db.verifyColumns()
    local missing = {}
    if not Db.available() then return missing end
    for _, req in ipairs(REQUIRED_COLUMNS) do
        local found = Db.scalar(('SHOW COLUMNS FROM `%s` LIKE ?'):format(req.table), { req.column })
        if not found then missing[#missing + 1] = req end
    end
    return missing
end

Boot.db = true
