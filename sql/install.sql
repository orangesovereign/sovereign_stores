-- ═══════════════════════════════════════════════════════════════════
-- SOVEREIGN STORES · INSTALL (idempotent — safe to re-run any time)
-- Full v1 schema per docs/02-FEATURES.md + design §13.
-- NOTE: physical store items live in Cas-inventory's custom-inventory
-- layer (character_inventories rows keyed by inventory_type
-- 'sovstore_<id>') — there is deliberately NO item-storage table here.
-- ═══════════════════════════════════════════════════════════════════

-- The store register: NPC and player stores share one table (class column).
CREATE TABLE IF NOT EXISTS `sovereign_stores` (
    `id`               INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `code`             CHAR(3)       NULL DEFAULT NULL,            -- player stores only; admin-set, immutable to players
    `class`            ENUM('npc','player') NOT NULL DEFAULT 'player',
    `name`             VARCHAR(64)   NOT NULL,
    `category`         VARCHAR(32)   NOT NULL DEFAULT 'general',
    `owner_charid`     INT           NULL DEFAULT NULL,
    `coowner_charid`   INT           NULL DEFAULT NULL,
    `status`           ENUM('open','closed','repossessed') NOT NULL DEFAULT 'closed',
    `purchase_price`   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    `tax_rate`         DECIMAL(5,2)  NOT NULL DEFAULT 0.00,        -- % of purchase_price, monthly
    `tax_due_date`     DATE          NULL DEFAULT NULL,
    `tax_state`        ENUM('current','delinquent') NOT NULL DEFAULT 'current',
    `delinquent_since` DATETIME      NULL DEFAULT NULL,            -- set on failed collection (72h clock)
    `inactivity_exempt_until` DATE   NULL DEFAULT NULL,            -- admin override (H6)
    `branding`         JSON          NULL,                         -- accent, motif, tagline, closed_message
    `webhook_url`      VARCHAR(255)  NULL,
    `webhook_events`   JSON          NULL,                         -- owner's event-type toggles
    `register_coords`  JSON          NULL,                         -- {x,y,z,h} (player stores)
    `npc_model`        VARCHAR(64)   NULL,                         -- cashier ped for this store
    `created_at`       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_store_code` (`code`),
    KEY `idx_class_status` (`class`, `status`),
    KEY `idx_owner` (`owner_charid`),
    KEY `idx_tax_due` (`tax_due_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- NPC multi-placement + roaming pools (design §2.1).
CREATE TABLE IF NOT EXISTS `sovereign_store_locations` (
    `id`         INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `store_id`   INT UNSIGNED  NOT NULL,
    `coords`     JSON          NOT NULL,                           -- {x,y,z}
    `heading`    DECIMAL(6,2)  NOT NULL DEFAULT 0.00,
    `npc_model`  VARCHAR(64)   NULL,                               -- overrides store npc_model
    `blip`       JSON          NULL,                               -- {sprite,label} — roaming stores: always NULL
    `is_active`  TINYINT(1)    NOT NULL DEFAULT 1,                 -- roaming: server marks the current pick
    PRIMARY KEY (`id`),
    KEY `idx_store` (`store_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sovereign_store_employees` (
    `id`          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `store_id`    INT UNSIGNED  NOT NULL,
    `charid`      INT           NOT NULL,
    `permissions` INT UNSIGNED  NOT NULL DEFAULT 0,                -- bitfield: STOCK|FUNDS_DEPOSIT|FUNDS_WITHDRAW|PRICES|STOREFRONT
    `pay_model`   ENUM('hourly','daily') NOT NULL DEFAULT 'hourly',
    `pay_rate`    DECIMAL(8,2)  NOT NULL DEFAULT 0.00,
    `hired_at`    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `hired_by`    INT           NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_store_char` (`store_id`, `charid`),
    KEY `idx_charid` (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Shelf stock: what buyers see. Quantity is the sellable count; the
-- physical intake sits in the custom-inventory storage.
CREATE TABLE IF NOT EXISTS `sovereign_store_stock` (
    `id`           INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `store_id`     INT UNSIGNED  NOT NULL,
    `item`         VARCHAR(64)   NOT NULL,
    `quantity`     INT           NOT NULL DEFAULT 0,
    `price`        DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    `sale_percent` TINYINT       NULL DEFAULT NULL,                -- active discount %
    `sale_ends_at` DATETIME      NULL DEFAULT NULL,
    `category`     VARCHAR(32)   NOT NULL DEFAULT 'general',
    `metadata`     JSON          NULL,                             -- exact-match stack identity (docs/05)
    PRIMARY KEY (`id`),
    KEY `idx_store` (`store_id`),
    KEY `idx_store_item` (`store_id`, `item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sovereign_store_buy_orders` (
    `id`         INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `store_id`   INT UNSIGNED  NOT NULL,
    `item`       VARCHAR(64)   NOT NULL,
    `unit_price` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    `qty_wanted` INT           NOT NULL DEFAULT 0,
    `qty_filled` INT           NOT NULL DEFAULT 0,
    `active`     TINYINT(1)    NOT NULL DEFAULT 1,                 -- auto-paused when ledger can't cover
    `created_at` TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_store_active` (`store_id`, `active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Typed transactions for BOTH ledgers (design §4): the money source of truth.
CREATE TABLE IF NOT EXISTS `sovereign_store_ledger` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `store_id`      INT UNSIGNED  NOT NULL,
    `account`       ENUM('operating','tax') NOT NULL DEFAULT 'operating',
    `type`          VARCHAR(24)   NOT NULL,                        -- sale|purchase|wage|deposit|withdrawal|tax_collected|adjustment|sweep
    `amount`        DECIMAL(10,2) NOT NULL,                        -- signed: + credits, - debits
    `balance_after` DECIMAL(12,2) NOT NULL,
    `actor_charid`  INT           NULL DEFAULT NULL,
    `item`          VARCHAR(64)   NULL DEFAULT NULL,
    `qty`           INT           NULL DEFAULT NULL,
    `note`          VARCHAR(255)  NULL DEFAULT NULL,
    `created_at`    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_store_account` (`store_id`, `account`),
    KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sovereign_store_timeclock` (
    `id`               INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `store_id`         INT UNSIGNED  NOT NULL,
    `charid`           INT           NOT NULL,
    `clock_in`         DATETIME      NOT NULL,
    `clock_out`        DATETIME      NULL DEFAULT NULL,
    `verified_minutes` INT           NOT NULL DEFAULT 0,           -- presence-heartbeat confirmed
    `paid`             TINYINT(1)    NOT NULL DEFAULT 0,
    `pay_amount`       DECIMAL(10,2) NULL DEFAULT NULL,            -- NULL until settled; unpaid shortfalls logged in ledger
    PRIMARY KEY (`id`),
    KEY `idx_store_char` (`store_id`, `charid`),
    KEY `idx_open_shifts` (`store_id`, `clock_out`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Staff panel: notes + restock checklists (design §10).
CREATE TABLE IF NOT EXISTS `sovereign_store_notes` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `store_id`   INT UNSIGNED NOT NULL,
    `charid`     INT          NOT NULL,
    `kind`       ENUM('note','restock') NOT NULL DEFAULT 'note',
    `content`    VARCHAR(500) NOT NULL,
    `checked`    TINYINT(1)   NOT NULL DEFAULT 0,                  -- restock items get ticked off
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_store_kind` (`store_id`, `kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Government-letter queue: F3 fallback while sovereign_postoffice SendMail
-- is a stub. A Phase 4 worker flushes 'queued' rows when mail goes live.
CREATE TABLE IF NOT EXISTS `sovereign_store_letters` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `recipient_charid` INT          NOT NULL,
    `subject`          VARCHAR(120) NOT NULL,
    `body`             TEXT         NOT NULL,
    `stationery`       VARCHAR(40)  NOT NULL DEFAULT 'county_letterhead',
    `status`           ENUM('queued','sent','failed') NOT NULL DEFAULT 'queued',
    `created_at`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `sent_at`          DATETIME     NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_status` (`status`),
    KEY `idx_recipient` (`recipient_charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Serial registry: global uniqueness via PK; generate → insert → retry on
-- collision. Cas-inventory does NOT auto-serial, so every serial here is ours.
CREATE TABLE IF NOT EXISTS `sovereign_weapon_serials` (
    `serial`          VARCHAR(12)  NOT NULL,                       -- CODE-XXXXXX
    `store_id`        INT UNSIGNED NOT NULL,
    `weapon`          VARCHAR(64)  NOT NULL,
    `sold_to_charid`  INT          NULL DEFAULT NULL,
    `created_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`serial`),
    KEY `idx_store` (`store_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- County treasury: NPC revenue, property taxes, repossession sweeps (design §4.3).
CREATE TABLE IF NOT EXISTS `sovereign_government_fund` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `type`          VARCHAR(24)   NOT NULL,                        -- npc_sale|tax|repossession_sweep|spend
    `amount`        DECIMAL(12,2) NOT NULL,                        -- signed
    `balance_after` DECIMAL(14,2) NOT NULL,
    `ref_store_id`  INT UNSIGNED  NULL DEFAULT NULL,
    `note`          VARCHAR(255)  NULL DEFAULT NULL,
    `created_at`    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_type` (`type`),
    KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Non-money event log (feature I1): hires, fires, permission changes,
-- branding edits, admin actions, repossessions. Money stays in
-- sovereign_store_ledger; webhooks mirror this, never replace it.
CREATE TABLE IF NOT EXISTS `sovereign_store_events` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `store_id`      INT UNSIGNED NULL DEFAULT NULL,      -- NULL = server-wide/admin
    `kind`          VARCHAR(32)  NOT NULL,               -- hired|fired|perms_changed|wage_set|open|close|branding|assigned|code_set|price_set|tax_rate_set|transfer|repossessed|adjustment
    `actor_charid`  INT          NULL DEFAULT NULL,
    `target_charid` INT          NULL DEFAULT NULL,
    `data`          JSON         NULL,
    `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_store_time` (`store_id`, `created_at`),
    KEY `idx_kind` (`kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
