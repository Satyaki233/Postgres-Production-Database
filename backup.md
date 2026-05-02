# Backup & Disaster Recovery Guide

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Backup Hierarchy](#2-backup-hierarchy)
3. [Scripts Reference](#3-scripts-reference)
4. [Running Backups Manually](#4-running-backups-manually)
5. [Scheduling Backups](#5-scheduling-backups)
6. [Stopping & Restarting the Schedule](#6-stopping--restarting-the-schedule)
7. [Verifying a Backup](#7-verifying-a-backup)
8. [Restoring Data](#8-restoring-data)
9. [Offsite Sync to S3 / Backblaze B2](#9-offsite-sync-to-s3--backblaze-b2)
10. [Cross-Platform Notes (Mac vs Linux)](#10-cross-platform-notes-mac-vs-linux)
11. [Recovery Runbooks](#11-recovery-runbooks)
12. [RPO / RTO Targets](#12-rpo--rto-targets)
13. [Further Reading](#13-further-reading)

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│  HOST MACHINE (Mac or Linux)                                            │
│                                                                         │
│  ┌──────────────────────────────────────┐   ┌────────────────────────┐ │
│  │   crontab (host-level scheduler)     │   │  backups/              │ │
│  │                                      │   │  ├── dumps/daily/      │ │
│  │  3:30am daily  → daily_dump.sh       │──▶│  ├── basebackup/       │ │
│  │  4:00am Sunday → daily_dump.sh       │   │  └── wal_archive/      │ │
│  │  1:30am Sunday → weekly_basebackup   │   └──────────┬─────────────┘ │
│  └──────────────────────────────────────┘              │               │
│                                                         │ offsite_sync  │
│  ┌──────────────────────────────────────┐              ▼               │
│  │   Docker Container: postgres_prod    │   ┌────────────────────────┐ │
│  │                                      │   │  S3 / Backblaze B2     │ │
│  │   pg_cron (inside PostgreSQL)        │   │  s3://bucket/          │ │
│  │   5:00am  → backup freshness check   │   │  postgres-dr/          │ │
│  │   5:30am  → backup storage report    │   └────────────────────────┘ │
│  │                                      │                              │
│  │   WAL archiver (continuous)          │──▶ backups/wal_archive/      │
│  └──────────────────────────────────────┘                              │
└─────────────────────────────────────────────────────────────────────────┘
```

**Key principle:** Backup scripts run on the **host** machine (not inside Docker). They use `docker exec` to call PostgreSQL tools from inside the container — this avoids client/server version mismatch (the host may have pg14, the container runs pg16).

**Three independent layers:**

| Layer      | Tool                      | Scope                    | When                       |
| ---------- | ------------------------- | ------------------------ | -------------------------- |
| Logical    | `pg_dump` (custom format) | Per-schema, compressed   | Daily                      |
| Physical   | `pg_basebackup`           | Full PGDATA filesystem   | Weekly                     |
| Continuous | WAL archiving             | Transaction log segments | Every write / every 1 hour |

WAL archiving + a basebackup together enable **Point-in-Time Recovery (PITR)** — you can restore to any minute in the past (not just the last daily snapshot).

---

## 2. Backup Hierarchy

The backups are structured in three tiers, from most granular to most complete:

```
backups/
├── dumps/
│   └── daily/
│       └── YYYY-MM-DD_HHmmss/       ← one directory per run
│           ├── MANIFEST              ← metadata (type, timestamp, size, pg version)
│           ├── globals.sql           ← roles, tablespaces (plain SQL)
│           ├── marts.dump            ← marts schema (custom format, compressed)
│           ├── staging.dump          ← staging schema (Sunday full only)
│           ├── raw.dump              ← raw schema (Sunday full only)
│           └── schema_only.sql       ← full DDL of all schemas (plain SQL)
│
├── basebackup/
│   ├── latest -> YYYY-MM-DD_HHmmss/ ← symlink to newest
│   └── YYYY-MM-DD_HHmmss/
│       ├── MANIFEST
│       ├── base.tar.gz              ← full PGDATA (tables, indexes, config)
│       └── pg_wal.tar.gz            ← WAL segments needed to make backup consistent
│
└── wal_archive/
    ├── 000000010000000A000000FF     ← WAL segment files (16 MB each)
    ├── 000000010000000B00000000
    └── ...                         ← deleted after 30 days via crontab
```

**Priority of layers for recovery:**

```
1. WAL archive  ── for point-in-time recovery (most precise, smallest individual files)
2. Basebackup   ── for full physical restore (fastest RTO for corruption scenarios)
3. pg_dump      ── for logical restore (best for accidental table drops/deletes)
```

**Why marts-only daily vs. full Sunday?**

`raw` and `staging` schemas are **regenerable** from source data via `tpcds/generate.sh` + `staging/transform.sql`. Running a full 3-schema dump daily would take ~45 min and write ~12 GB. The daily marts-only dump takes ~12 min and writes ~2.5 GB — protecting only the work that can't be regenerated quickly.

---

## 3. Scripts Reference

All scripts live in `scripts/backup/` and must be run from the project root or with the full path.

### `daily_dump.sh`

Logical per-schema backup using `pg_dump` (custom format, level-9 compressed).

```bash
bash scripts/backup/daily_dump.sh [--marts-only | --full]
```

| Flag                     | What it dumps         | Typical size | Time    |
| ------------------------ | --------------------- | ------------ | ------- |
| `--marts-only` (default) | marts schema only     | ~2.5 GB      | ~12 min |
| `--full`                 | marts + staging + raw | ~12 GB       | ~45 min |

**Output:** `backups/dumps/daily/YYYY-MM-DD_HHmmss/`

**After running:** Calls `offsite_sync.sh --dumps-only` automatically if `ENABLE_OFFSITE_SYNC=true` (default).

### `weekly_basebackup.sh`

Physical full-PGDATA backup using `pg_basebackup`.

```bash
bash scripts/backup/weekly_basebackup.sh
```

Streams WAL during the backup (`--wal-method=stream`) so the result is self-contained. No WAL archive is needed to restore from it.

**Output:** `backups/basebackup/YYYY-MM-DD_HHmmss/`

**After running:** Calls `offsite_sync.sh` (full sync) automatically.

### `verify_backup.sh`

Checks backup integrity without restoring. Safe to run at any time.

```bash
# Check the most recent dump
bash scripts/backup/verify_backup.sh --latest-dump

# Check the most recent basebackup
bash scripts/backup/verify_backup.sh --latest-basebackup

# Check a specific backup directory
bash scripts/backup/verify_backup.sh --dump     backups/dumps/daily/2026-05-02_145734
bash scripts/backup/verify_backup.sh --basebackup backups/basebackup/2026-05-05_013000
```

Checks performed:

- MANIFEST file exists and is readable
- Each `.dump` file is non-empty and has valid PostgreSQL magic bytes (`PGDMP`)
- `schema_only.sql` contains `CREATE TABLE` statements
- `globals.sql` is non-empty
- `base.tar.gz` passes `tar -tzf` integrity test
- `PG_VERSION` and `postgresql.conf` exist inside `base.tar.gz`
- `pg_wal.tar.gz` exists and passes tar integrity test

### `restore.sh`

Unified restore entry point. All destructive actions require `--confirm`.

```bash
# See what backups are available
bash scripts/backup/restore.sh --list-backups

# Preview what would happen (no changes)
bash scripts/backup/restore.sh --from-dump --schema marts --dry-run
bash scripts/backup/restore.sh --from-basebackup --dry-run

# Execute restore
bash scripts/backup/restore.sh --from-dump --schema marts --confirm
bash scripts/backup/restore.sh --from-basebackup --confirm
```

Options:

| Option              | Description                                            |
| ------------------- | ------------------------------------------------------ |
| `--from-dump`       | Logical restore (one schema stays online)              |
| `--from-basebackup` | Physical restore (stops all services, replaces volume) |
| `--dir PATH`        | Use a specific backup directory instead of latest      |
| `--schema NAME`     | Which schema to restore (default: `marts`)             |
| `--schema all`      | Restore all schemas found in the dump directory        |
| `--dry-run`         | Print steps, make no changes                           |
| `--confirm`         | Required to execute destructive actions                |

### `offsite_sync.sh`

Syncs local backups to S3 or Backblaze B2.

```bash
bash scripts/backup/offsite_sync.sh               # sync everything
bash scripts/backup/offsite_sync.sh --dumps-only  # sync pg_dump backups only
bash scripts/backup/offsite_sync.sh --dry-run     # show what would sync
```

Requires `BACKUP_BUCKET` in `.env`. See [Section 9](#9-offsite-sync-to-s3--backblaze-b2).

---

## 4. Running Backups Manually

Always run from the project root directory:

```bash
cd "/path/to/Postgres Production Database"

# Daily marts backup (most common)
bash scripts/backup/daily_dump.sh --marts-only

# Full backup of all schemas
bash scripts/backup/daily_dump.sh --full

# Physical full backup (takes 10–20 minutes)
bash scripts/backup/weekly_basebackup.sh

# Verify the latest backup afterward
bash scripts/backup/verify_backup.sh --latest-dump
```

If you need to disable the automatic offsite sync for a manual run:

```bash
ENABLE_OFFSITE_SYNC=false bash scripts/backup/daily_dump.sh --marts-only
```

---

## 5. Scheduling Backups

Backups are scheduled via the **host OS crontab** — not inside Docker. This means they keep running even if the container restarts, and the schedule survives container recreations.

### Setting up the crontab

```bash
crontab -e
```

Add these lines (paste exactly, adjust the path if you moved the project):

```cron
# ── PostgreSQL Data Warehouse Backups ──────────────────────────────────────────

# Daily marts-only dump at 3:30am (after pg_cron VACUUM at 2:30am)
30 3 * * *  cd "/Users/apple/Satyaki/Postgres Production Database" && bash scripts/backup/daily_dump.sh --marts-only >> /tmp/pg_backup_cron.log 2>&1

# Full dump (all schemas) every Sunday at 4:00am
0 4 * * 0   cd "/Users/apple/Satyaki/Postgres Production Database" && bash scripts/backup/daily_dump.sh --full >> /tmp/pg_backup_cron.log 2>&1

# Weekly physical basebackup every Sunday at 1:30am
30 1 * * 0  cd "/Users/apple/Satyaki/Postgres Production Database" && bash scripts/backup/weekly_basebackup.sh >> /tmp/pg_backup_cron.log 2>&1

# WAL archive cleanup: delete WAL files older than 30 days
0 5 * * *   find "/Users/apple/Satyaki/Postgres Production Database/backups/wal_archive" -name "0000*" -mtime +30 -delete >> /tmp/pg_backup_cron.log 2>&1
```

**Cron time format:** `minute hour day-of-month month day-of-week`

**Timing rationale:**

- `1:30am Sunday`: basebackup starts after pg_partman maintenance (1am)
- `3:30am daily`: dump starts after nightly VACUUM ANALYZE finishes (2:30am)
- `4:00am Sunday`: full dump runs after basebackup completes (1:30am + ~20 min)

### Verifying the crontab is active

```bash
crontab -l
```

### Viewing cron job logs

```bash
tail -f /tmp/pg_backup_cron.log
```

### On Linux (systemd timer alternative)

On Linux servers, you can use systemd timers instead of crontab for better logging and failure notifications. However, crontab works on both macOS and Linux and is simpler for a single-machine setup.

---

## 6. Stopping & Restarting the Schedule

### Temporarily disable all backup jobs

```bash
# Export current crontab to a file
crontab -l > /tmp/my_crontab_backup.txt

# Remove all cron jobs
crontab -r

# Verify (should show no output)
crontab -l
```

### Re-enable backup jobs

```bash
# Restore from the saved file
crontab /tmp/my_crontab_backup.txt

# Or edit and re-add manually
crontab -e
```

### Disable a single job without deleting it

Edit the crontab and add `#` at the start of the line:

```bash
crontab -e
# Change:
#   30 3 * * * cd "..." && bash scripts/backup/daily_dump.sh ...
# To:
#   #30 3 * * * cd "..." && bash scripts/backup/daily_dump.sh ...
```

### Stop a running backup

If a backup is running and you need to stop it:

```bash
# Find the process
ps aux | grep daily_dump

# Kill it
kill <PID>

# If it's a pg_dump inside the container, cancel it inside PostgreSQL
docker exec -e PGPASSWORD=$POSTGRES_PASSWORD postgres_production \
  psql -U satyaki -d warehouse \
  -c "SELECT pg_cancel_backend(pid) FROM pg_stat_activity WHERE query LIKE '%pg_dump%';"
```

### Pause WAL archiving (without a restart)

WAL archiving can be paused via SQL if you need to stop WAL files from accumulating temporarily:

```sql
-- Pause archiving (WAL files queue in pg_wal but are not archived)
ALTER SYSTEM SET archive_mode = 'always';  -- this actually can't be changed without restart

-- The clean way: set a no-op archive command temporarily
ALTER SYSTEM SET archive_command = '/bin/true';
SELECT pg_reload_conf();

-- Resume
ALTER SYSTEM SET archive_command = 'test ! -f /var/lib/postgresql/wal_archive/%f && cp %p /var/lib/postgresql/wal_archive/%f';
SELECT pg_reload_conf();
```

---

## 7. Verifying a Backup

Always verify after a backup before relying on it for recovery.

```bash
# Verify latest dump
bash scripts/backup/verify_backup.sh --latest-dump

# Verify latest basebackup
bash scripts/backup/verify_backup.sh --latest-basebackup

# Expected output (all PASS):
# [PASS] MANIFEST file exists
# [PASS] marts.dump is non-empty (2.5G)
# [PASS] marts.dump has valid PostgreSQL custom format magic (PGDMP)
# [PASS] schema_only.sql contains CREATE TABLE statements
# [PASS] globals.sql is non-empty
# RESULT: BACKUP VERIFIED SUCCESSFULLY
```

Check the backup log table inside PostgreSQL:

```sql
SELECT backup_type, started_at, status, pg_size_pretty(size_bytes), duration_secs, notes
FROM public.backup_log
ORDER BY started_at DESC
LIMIT 10;
```

---

## 8. Restoring Data

### Before any restore

1. Identify which backup to use: `bash scripts/backup/restore.sh --list-backups`
2. Verify it: `bash scripts/backup/verify_backup.sh --latest-dump`
3. Do a dry run first: add `--dry-run` to the restore command

### Restore a single schema from pg_dump

This keeps the database online. Only the target schema is affected.

```bash
# Restore just the marts schema (most common scenario)
bash scripts/backup/restore.sh \
  --from-dump \
  --schema marts \
  --dry-run          # preview first

bash scripts/backup/restore.sh \
  --from-dump \
  --schema marts \
  --confirm          # execute

# Restore from a specific date (not latest)
bash scripts/backup/restore.sh \
  --from-dump \
  --dir backups/dumps/daily/2026-05-01_033000 \
  --schema marts \
  --confirm
```

### Restore full PGDATA from basebackup

This stops all services, replaces the Docker volume, and restarts. Use for container/volume corruption.

```bash
bash scripts/backup/restore.sh --from-basebackup --dry-run
bash scripts/backup/restore.sh --from-basebackup --confirm
```

### Validate after restore

```bash
# Check row counts
psql -h 127.0.0.1 -p 5434 -U satyaki -d warehouse \
  -c "SELECT schemaname, relname, n_live_tup
      FROM pg_stat_user_tables
      WHERE schemaname = 'marts'
      ORDER BY n_live_tup DESC;"

# Expected:
# fact_store_sales_default  ~28,800,000
# fact_catalog_sales_default ~14,400,000
# fact_web_sales_default     ~7,200,000
# dim_customer               ~500,000
```

---

## 9. Offsite Sync to S3 / Backblaze B2

Local backups protect against accidental deletion and container failure. For true disaster recovery (host failure, fire, theft), you need offsite storage.

### Setup

Add to your `.env` file:

```bash
# Required
BACKUP_BUCKET=your-bucket-name

# Option A: AWS S3
AWS_PROFILE=default          # profile name from ~/.aws/credentials

# Option B: Backblaze B2 (S3-compatible)
B2_ENDPOINT_URL=https://s3.us-west-004.backblazeb2.com
AWS_ACCESS_KEY_ID=your-b2-keyid
AWS_SECRET_ACCESS_KEY=your-b2-appkey
```

Install the AWS CLI (works for both S3 and Backblaze B2):

```bash
# macOS
brew install awscli

# Linux (Debian/Ubuntu)
apt-get install awscli
# or
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip && \
  unzip awscliv2.zip && sudo ./aws/install
```

### Test the sync

```bash
bash scripts/backup/offsite_sync.sh --dry-run
```

### Manual sync

```bash
bash scripts/backup/offsite_sync.sh
```

### Download backups from cloud (disaster recovery)

```bash
# AWS S3
aws s3 sync s3://your-bucket/postgres-dr/ ./backups/

# Backblaze B2
aws s3 sync s3://your-bucket/postgres-dr/ ./backups/ \
  --endpoint-url https://s3.us-west-004.backblazeb2.com
```

---

## 10. Cross-Platform Notes (Mac vs Linux)

All scripts are written to work on both **macOS** and **Linux**. Key differences handled:

| Operation          | macOS             | Linux       | How scripts handle it                  |
| ------------------ | ----------------- | ----------- | -------------------------------------- |
| File size in bytes | `stat -f%z`       | `stat -c%s` | `stat -f%z 2>/dev/null \|\| stat -c%s` |
| Directory size     | `du -sh` (human)  | same        | `find ... -ls \| awk` for bytes        |
| `du -sb` (bytes)   | **not supported** | supported   | replaced with `find ... \| awk`        |
| `pg_dump` version  | host may be pg14  | varies      | all pg commands via `docker exec`      |

The safest rule: **always run backup commands via `docker exec`** rather than calling host `pg_dump`/`pg_restore` directly. This ensures you always use the pg16 binaries that match your server.

### On Linux: macOS-specific `crontab` vs system cron

On Linux servers, the crontab setup is identical (`crontab -e`). The syntax is the same. The only difference: replace `/Users/apple/Satyaki/Postgres Production Database` with your actual project path.

On Linux with systemd you can optionally use a timer unit for better logging:

```ini
# /etc/systemd/system/pg-daily-dump.timer
[Unit]
Description=Daily PostgreSQL dump

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/pg-daily-dump.service
[Unit]
Description=Daily PostgreSQL dump

[Service]
Type=oneshot
WorkingDirectory=/opt/postgres-dw
ExecStart=/bin/bash scripts/backup/daily_dump.sh --marts-only
User=youruser
```

---

## 11. Recovery Runbooks

### Scenario A — Accidental data deletion (RTO: ~45 min)

**Symptoms:** Wrong `DELETE`/`DROP TABLE`/`TRUNCATE` was run.

```bash
# 1. List backups to find a good restore point
bash scripts/backup/restore.sh --list-backups

# 2. Verify the backup you plan to use
bash scripts/backup/verify_backup.sh --dump backups/dumps/daily/2026-05-01_033000

# 3. Preview the restore
bash scripts/backup/restore.sh \
  --from-dump \
  --dir backups/dumps/daily/2026-05-01_033000 \
  --schema marts \
  --dry-run

# 4. Execute (database stays online for other schemas)
bash scripts/backup/restore.sh \
  --from-dump \
  --dir backups/dumps/daily/2026-05-01_033000 \
  --schema marts \
  --confirm

# 5. Run VACUUM ANALYZE after restore
psql -h 127.0.0.1 -p 5434 -U satyaki -d warehouse \
  -c "VACUUM ANALYZE marts.fact_store_sales; VACUUM ANALYZE marts.dim_customer;"
```

**If you need a specific table only** (not the whole schema):

```bash
docker exec -i -e PGPASSWORD=$POSTGRES_PASSWORD postgres_production \
  pg_restore \
    -U satyaki -h 127.0.0.1 -d warehouse \
    --table=fact_store_sales \
    --data-only \
  < backups/dumps/daily/2026-05-01_033000/marts.dump
```

---

### Scenario B — Container / volume corruption (RTO: ~20 min)

**Symptoms:** Container fails to start, PostgreSQL log shows PANIC or "invalid page header".

```bash
# 1. Confirm the problem
docker logs postgres_production --tail=30

# 2. Verify the physical backup
bash scripts/backup/verify_backup.sh --latest-basebackup

# 3. Preview
bash scripts/backup/restore.sh --from-basebackup --dry-run

# 4. Execute (stops all 5 services, replaces volume, restarts)
bash scripts/backup/restore.sh --from-basebackup --confirm

# 5. Check all services recovered
docker compose ps
```

---

### Scenario C — Full host failure (RTO: 30–60 min with backups)

**On a new machine:**

```bash
# 1. Install: Git, Docker Desktop, AWS CLI
# 2. Clone the repo
git clone <your-remote-url> "Postgres Production Database"
cd "Postgres Production Database"

# 3. Restore .env (from password manager)
# Add: POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB, GRAFANA_PASSWORD, BACKUP_BUCKET

# 4. Create backup directories
mkdir -p backups/{dumps/daily,basebackup,volumes,wal_archive}
chmod 777 backups/wal_archive

# 5. Download backups from S3/B2
aws s3 sync s3://your-bucket/postgres-dr/ ./backups/

# 6. Start stack (builds custom Docker image)
docker compose up -d --build

# 7. Restore the database
bash scripts/backup/restore.sh --from-basebackup --confirm

# 8. Apply backup monitoring table (only needed on fresh container)
psql -h 127.0.0.1 -p 5434 -U satyaki -d warehouse -f init/04_backup_log.sql

# 9. Re-add crontab
crontab -e   # paste lines from Section 5

# 10. Verify everything
bash scripts/backup/verify_backup.sh --latest-dump
docker compose ps
```

**If no backups are available (full rebuild, ~2–3 hours):**

```bash
docker compose up -d --build
psql -h 127.0.0.1 -p 5434 -U satyaki -d warehouse -f tpcds/schema/tpcds.sql
bash tpcds/generate.sh      # ~25 min
bash tpcds/load.sh          # ~30 min
psql ... -f staging/transform.sql    # ~15 min
psql ... -f marts/create_marts.sql   # ~45 min
psql ... -f marts/indexes.sql        # ~15 min
```

---

## 12. RPO / RTO Targets

| Scenario                                  | RPO (max data loss) | RTO (time to recover) |
| ----------------------------------------- | ------------------- | --------------------- |
| Accidental deletion (pg_dump restore)     | 24 hours            | 45–90 min             |
| Container/volume corruption (basebackup)  | 24 hours            | 15–30 min             |
| Full host failure with cloud backups      | 24 hours            | 30–60 min             |
| Point-in-time recovery (WAL + basebackup) | 1 hour              | 30–60 min             |
| Full rebuild from scratch (no backups)    | N/A                 | 2.5–4 hours           |

**RPO explanation:** If your last backup was at 3:30am and a failure happens at 11pm, you lose ~20 hours of changes. For a batch-loaded OLAP warehouse (data doesn't change continuously), this is typically acceptable — you re-run the load pipeline to catch up.

**WAL archiving reduces RPO to ~1 hour** even between daily backups. Each WAL segment is archived to disk within 1 hour (configured via `archive_timeout = 3600`).

---

## 13. Further Reading

### PostgreSQL Official Documentation

- **[pg_dump](https://www.postgresql.org/docs/16/app-pgdump.html)** — logical backup tool, all flags explained
- **[pg_basebackup](https://www.postgresql.org/docs/16/app-pgbasebackup.html)** — physical backup tool
- **[pg_restore](https://www.postgresql.org/docs/16/app-pgrestore.html)** — restore from pg_dump custom format
- **[WAL Archiving & PITR](https://www.postgresql.org/docs/16/continuous-archiving.html)** — continuous archiving, recovery.conf, pg_wal
- **[Backup & Restore chapter](https://www.postgresql.org/docs/16/backup.html)** — overview of all three methods (SQL dump, file-system, continuous)
- **[pg_stat_archiver](https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ARCHIVER-VIEW)** — monitor WAL archiving health

### Books

- **"PostgreSQL: Up and Running" (O'Reilly)** — Chapter 11 covers backup strategies in depth
- **"The Art of PostgreSQL" (Dimitri Fontaine)** — practical production patterns

### Concepts to study

| Concept                            | Why it matters here                                                                                                                  |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **WAL (Write-Ahead Log)**          | Foundation of PITR — understanding WAL explains why `archive_timeout` bounds your RPO                                                |
| **Custom vs directory format**     | `pg_dump -Fc` (custom) supports parallel restore and selective table restore; `-Fd` (directory) supports parallel dump               |
| **Tablespace-aware restores**      | If you ever use non-default tablespaces, pg_restore needs `--tablespace-map`                                                         |
| **pg_dump vs logical replication** | pg_dump is a point-in-time snapshot; logical replication is continuous. For near-zero RPO, logical replication is the next step.     |
| **Docker volume backup patterns**  | Volumes are best backed up via database tools (pg_dump/pg_basebackup), not raw filesystem tar — avoids partial-write inconsistencies |

### Monitoring backup health

Inside your Grafana dashboard, you can add a panel that queries `public.backup_log`:

```sql
SELECT backup_type, MAX(started_at) AS last_run,
       EXTRACT(EPOCH FROM (now() - MAX(started_at)))/3600 AS hours_ago
FROM public.backup_log
WHERE status = 'success'
GROUP BY backup_type;
```

pg_cron raises `WARNING`-level log messages when backups are stale (daily check at 5am). These appear in the PostgreSQL log and can be surfaced in Grafana's log panel via the Loki datasource or postgres_exporter log metrics.
