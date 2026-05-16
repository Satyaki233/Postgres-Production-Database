-- ==========================================
-- BACKUP MONITORING INFRASTRUCTURE
-- Creates backup_log table for tracking backup history.
-- Applied automatically on fresh container init.
-- For existing containers, apply manually:
--   psql -h 127.0.0.1 -p 5434 -U satyaki -d warehouse -f init/04_backup_log.sql
-- ==========================================

CREATE TABLE IF NOT EXISTS public.backup_log (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    backup_type    TEXT        NOT NULL,   -- 'pg_dump_marts', 'pg_dump_full', 'pg_basebackup'
    started_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    status         TEXT        NOT NULL,   -- 'success', 'failed'
    size_bytes     BIGINT,
    duration_secs  INTEGER,
    notes          TEXT
);

CREATE INDEX IF NOT EXISTS idx_backup_log_type_started
    ON public.backup_log (backup_type, started_at DESC);

GRANT SELECT ON public.backup_log TO warehouse_analyst;
GRANT ALL    ON public.backup_log TO warehouse_developer;
