-- ==========================================
-- SCHEDULED MAINTENANCE JOBS
-- Requires pg_cron extension (loaded via shared_preload_libraries)
-- ==========================================

-- Nightly VACUUM ANALYZE on fact tables (2am)
SELECT cron.schedule(
  'nightly-vacuum-facts',
  '0 2 * * *',
  $$VACUUM ANALYZE marts.fact_store_sales, marts.fact_web_sales, marts.fact_catalog_sales$$
);

-- Nightly VACUUM ANALYZE on dimension tables (2:30am)
SELECT cron.schedule(
  'nightly-vacuum-dims',
  '30 2 * * *',
  $$VACUUM ANALYZE marts.dim_date, marts.dim_customer, marts.dim_item, marts.dim_store, marts.dim_promotion$$
);

-- Weekly pg_partman maintenance — pre-creates next partitions (Sunday 1am)
SELECT cron.schedule(
  'weekly-partition-maintenance',
  '0 1 * * 0',
  $$SELECT partman.run_maintenance(p_analyze := true)$$
);

-- Weekly pg_stat_statements reset to keep stats fresh (Sunday 3am)
SELECT cron.schedule(
  'weekly-stat-reset',
  '0 3 * * 0',
  $$SELECT pg_stat_statements_reset()$$
);

-- ==========================================
-- BACKUP MONITORING JOBS
-- These jobs run INSIDE PostgreSQL and check whether host-side backup scripts
-- have been logging their results to public.backup_log.
-- They raise WARNING to the PostgreSQL log (visible in Grafana log panels).
-- They do NOT trigger backups — backups run from host crontab.
-- ==========================================

-- Daily at 5am: alert if no successful pg_dump in last 26 hours
SELECT cron.schedule(
  'backup-freshness-check',
  '0 5 * * *',
  $$
  DO $body$
  DECLARE
    last_backup TIMESTAMPTZ;
    hours_ago   NUMERIC;
  BEGIN
    SELECT MAX(started_at)
    INTO   last_backup
    FROM   public.backup_log
    WHERE  backup_type LIKE 'pg_dump%'
      AND  status = 'success';

    IF last_backup IS NULL THEN
      RAISE WARNING 'DR_ALERT: No successful pg_dump backup found in backup_log. Check host crontab.';
    ELSE
      hours_ago := EXTRACT(EPOCH FROM (now() - last_backup)) / 3600;
      IF hours_ago > 26 THEN
        RAISE WARNING 'DR_ALERT: Last pg_dump was %.1f hours ago (threshold: 26h). Check host crontab.', hours_ago;
      ELSE
        RAISE NOTICE 'DR_CHECK: Last pg_dump was %.1f hours ago. OK.', hours_ago;
      END IF;
    END IF;
  END;
  $body$ LANGUAGE plpgsql;
  $$
);

-- Monday 5am: alert if no pg_basebackup in last 8 days
SELECT cron.schedule(
  'basebackup-freshness-check',
  '0 5 * * 1',
  $$
  DO $body$
  DECLARE
    last_backup TIMESTAMPTZ;
    days_ago    NUMERIC;
  BEGIN
    SELECT MAX(started_at)
    INTO   last_backup
    FROM   public.backup_log
    WHERE  backup_type = 'pg_basebackup'
      AND  status = 'success';

    IF last_backup IS NULL THEN
      RAISE WARNING 'DR_ALERT: No successful pg_basebackup found in backup_log. Check host crontab.';
    ELSE
      days_ago := EXTRACT(EPOCH FROM (now() - last_backup)) / 86400;
      IF days_ago > 8 THEN
        RAISE WARNING 'DR_ALERT: Last pg_basebackup was %.1f days ago (threshold: 8d). Check host crontab.', days_ago;
      ELSE
        RAISE NOTICE 'DR_CHECK: Last pg_basebackup was %.1f days ago. OK.', days_ago;
      END IF;
    END IF;
  END;
  $body$ LANGUAGE plpgsql;
  $$
);

-- Daily at 5:30am: log backup storage stats (visible in PostgreSQL log / Grafana)
SELECT cron.schedule(
  'backup-storage-report',
  '30 5 * * *',
  $$
  DO $body$
  DECLARE
    rec RECORD;
  BEGIN
    FOR rec IN
      SELECT backup_type,
             COUNT(*)                              AS total_backups,
             pg_size_pretty(SUM(size_bytes)::BIGINT) AS total_size,
             MAX(started_at)                       AS latest
      FROM   public.backup_log
      WHERE  status = 'success'
        AND  started_at > now() - INTERVAL '30 days'
      GROUP BY backup_type
      ORDER BY backup_type
    LOOP
      RAISE NOTICE 'DR_STATS: type=% count=% total_size=% latest=%',
        rec.backup_type, rec.total_backups, rec.total_size, rec.latest;
    END LOOP;
  END;
  $body$ LANGUAGE plpgsql;
  $$
);
