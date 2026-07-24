--[[=====================================================================
  SOVEREIGN STORES · WEAPON SERIAL REGISTRY (design §9, feature D8)
  Serial format CODE-XXXXXX. Global uniqueness via the registry PK:
  generate → tryInsert → retry on collision. Cas-inventory does not
  auto-serial (docs/05), so every serial on the server is one of ours.
=====================================================================]]--

Serials = {}

local MAX_TRIES <const> = 6

---Reserve a unique serial for a weapon sold by a store.
---@return string|nil serial
function Serials.issue(storeId, code, weaponName, soldToCharid)
    if type(code) ~= 'string' or #code ~= 3 then return nil end
    for _ = 1, MAX_TRIES do
        local serial = ('%s-%06d'):format(code:upper(), math.random(0, 999999))
        local ok = Db.tryInsert(
            'INSERT INTO sovereign_weapon_serials (serial, store_id, weapon, sold_to_charid) VALUES (?, ?, ?, ?)',
            { serial, storeId, weaponName, soldToCharid })
        if ok then return serial end
    end
    Util.err(('serials: %d collisions in a row for code %s — registry crowded?'):format(MAX_TRIES, code))
    return nil
end

---Law-RP lookup: who sold this weapon?
function Serials.lookup(serial)
    local rows = Db.query(
        [[SELECT s.serial, s.weapon, s.sold_to_charid, s.created_at, st.name AS store_name, st.code
          FROM sovereign_weapon_serials s
          LEFT JOIN sovereign_stores st ON st.id = s.store_id
          WHERE s.serial = ?]],
        { tostring(serial):upper() })
    return rows and rows[1] or nil
end

-- Integration surface: other scripts (law MDT) can trace a serial.
exports('LookupWeaponSerial', function(serial)
    return Serials.lookup(serial)
end)
