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
