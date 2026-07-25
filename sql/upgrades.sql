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
