-- ═══════════════════════════════════════════════════════════════════
-- SOVEREIGN STORES · UPGRADES (append-only, dated, idempotent)
-- Existing installs run new blocks top-to-bottom; every block must be
-- safe to re-run ("check first, do nothing if already done").
-- Fresh installs never need this file — install.sql is always complete.
-- ═══════════════════════════════════════════════════════════════════

-- (no upgrades yet — schema born 2026-07-23 at v0.1.0)

-- ── 2026-07-24 · Phase 2 foundation ──────────────────────────────────
-- Event log table (feature I1). Idempotent.
CREATE TABLE IF NOT EXISTS `sovereign_store_events` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `store_id`      INT UNSIGNED NULL DEFAULT NULL,
    `kind`          VARCHAR(32)  NOT NULL,
    `actor_charid`  INT          NULL DEFAULT NULL,
    `target_charid` INT          NULL DEFAULT NULL,
    `data`          JSON         NULL,
    `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_store_time` (`store_id`, `created_at`),
    KEY `idx_kind` (`kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────────────────────────────
-- 2026-07-24b · Phase 3 (staff systems) — CORRECTED 2026-07-25
-- Per-item low-stock threshold on the shelf.
-- The original block used `ADD COLUMN IF NOT EXISTS`, which is
-- MariaDB-only — on MySQL it errors and the column never lands (ledger
-- Phase 3 D2). This form checks information_schema first and runs clean
-- on BOTH engines, truly idempotent: re-runs print no errors at all.
-- ─────────────────────────────────────────────────────────────────────
SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sovereign_store_stock'
      AND COLUMN_NAME = 'low_threshold'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `sovereign_store_stock` ADD COLUMN `low_threshold` INT NULL DEFAULT NULL AFTER `category`',
    'SELECT 1');
PREPARE upgrade_20260724b FROM @ddl;
EXECUTE upgrade_20260724b;
DEALLOCATE PREPARE upgrade_20260724b;

-- ─────────────────────────────────────────────────────────────────────
-- 2026-07-30 · Phase 5 (analytics)
-- Item-level sales record. Idempotent — CREATE TABLE IF NOT EXISTS.
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `sovereign_store_sale_items` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `store_id`   INT UNSIGNED  NULL DEFAULT NULL,
    `store_key`  VARCHAR(32)   NULL DEFAULT NULL,
    `kind`       ENUM('sale','purchase') NOT NULL DEFAULT 'sale',
    `item`       VARCHAR(64)   NOT NULL,
    `qty`        INT           NOT NULL DEFAULT 0,
    `unit_price` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    `gross`      DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    `charid`     INT           NULL DEFAULT NULL,
    `created_at` TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_store_time` (`store_id`, `created_at`),
    KEY `idx_item_time` (`item`, `created_at`),
    KEY `idx_kind_time` (`kind`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────────────────────────────
-- 2026-08-09 · Stores are one-off (owner ruling)
-- A store is a PERSON'S business, not a reusable fixture. Every ending —
-- sold back, seized for tax, charter revoked for absence — retires it.
-- The record survives (weapon-serial provenance depends on it) but it
-- leaves the working directory, freeing the premises for a new charter.
-- MODIFY COLUMN is naturally idempotent; the columns use the same
-- information_schema guard as every other block here.
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE `sovereign_stores`
    MODIFY COLUMN `status` ENUM('open','closed','repossessed','archived') NOT NULL DEFAULT 'closed';

SET @c := (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sovereign_stores'
             AND COLUMN_NAME = 'archived_at');
SET @s := IF(@c = 0,
    'ALTER TABLE `sovereign_stores` ADD COLUMN `archived_at` DATETIME NULL DEFAULT NULL',
    'SELECT 1');
PREPARE up_20260809a FROM @s; EXECUTE up_20260809a; DEALLOCATE PREPARE up_20260809a;

SET @c := (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sovereign_stores'
             AND COLUMN_NAME = 'archive_reason');
SET @s := IF(@c = 0,
    'ALTER TABLE `sovereign_stores` ADD COLUMN `archive_reason` VARCHAR(64) NULL DEFAULT NULL',
    'SELECT 1');
PREPARE up_20260809b FROM @s; EXECUTE up_20260809b; DEALLOCATE PREPARE up_20260809b;

-- ─────────────────────────────────────────────────────────────────────
-- 2026-08-14 · One tax authority per store (owner ruling)
-- A store on a realty business property is already taxed by
-- sovereign_banking (sovereign_realestate hands it over with
-- RegisterBusiness at purchase). Those stores must NOT also be assessed
-- here — that was two bills and two repossession paths on one property.
-- NULL = the county assesses it (a store chartered outside realty).
-- ─────────────────────────────────────────────────────────────────────
SET @c := (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sovereign_stores'
             AND COLUMN_NAME = 'tax_authority');
SET @s := IF(@c = 0,
    'ALTER TABLE `sovereign_stores` ADD COLUMN `tax_authority` VARCHAR(32) NULL DEFAULT NULL',
    'SELECT 1');
PREPARE up_20260814 FROM @s; EXECUTE up_20260814; DEALLOCATE PREPARE up_20260814;

-- ─────────────────────────────────────────────────────────────────────
-- 2026-08-16 · One shop, one inventory (owner ruling)
-- A store chartered on a realty business property shares that property's
-- stash rather than keeping a second back room of its own. The owning
-- resource registers and sizes the inventory; we only address it. NULL =
-- our own sovstore_<id>, exactly as before.
-- ─────────────────────────────────────────────────────────────────────
SET @c := (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sovereign_stores'
             AND COLUMN_NAME = 'storage_id');
SET @s := IF(@c = 0,
    'ALTER TABLE `sovereign_stores` ADD COLUMN `storage_id` VARCHAR(64) NULL DEFAULT NULL',
    'SELECT 1');
PREPARE up_20260816 FROM @s; EXECUTE up_20260816; DEALLOCATE PREPARE up_20260816;
