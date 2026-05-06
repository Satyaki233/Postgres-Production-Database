# AWS ECS Deployment Plan — PostgreSQL Data Warehouse

## Overview

This document covers the changes needed to deploy the PostgreSQL warehouse on AWS ECS
and migrate the bash-based backup system to work in that environment.

---

## The Core Problem

The current backup system has four assumptions that break on ECS:

| Current Assumption | ECS Reality |
|---|---|
| `docker exec` into a named container | No host-level container access |
| `docker cp` to extract files | Containers are ephemeral, no host filesystem |
| Host `crontab` for scheduling | No persistent host to run cron |
| Local `backups/` directory | Filesystem is lost when task stops |

---

## Target Architecture

```
EventBridge Scheduler
       │
       ▼
  Backup ECS Task (separate task definition)
  ┌────────────────────────────────┐
  │  postgres:16 image             │
  │  pg_dump ──────────────────────┼──▶ S3 (via pipe, no local disk)
  │  connects via TCP to Postgres  │
  └────────────────────────────────┘
          │ TCP :5432
          ▼
  Postgres ECS Task (main service)
  ┌────────────────────────────────┐
  │  warehouse container           │
  │  archive_command ──────────────┼──▶ S3 (WAL streaming)
  └────────────────────────────────┘
```

---

## Component Migration Plan

### 1. Replace `docker exec pg_dump` → Dedicated Backup ECS Task

Create a **separate ECS Task Definition** (not a sidecar) that runs a lightweight backup
container on demand. `pg_dump` connects to the Postgres service via TCP — it does not
need to run inside the Postgres container.

```bash
# New backup invocation (runs inside the backup ECS task):
pg_dump \
  --host=$PGHOST \
  --username=$PGUSER \
  --dbname=warehouse \
  --schema=marts \
  --format=custom \
  --compress=9 \
  --no-password \
| aws s3 cp - "s3://$BACKUP_BUCKET/postgres-dr/dumps/$(date +%Y-%m-%d_%H%M%S)/marts.dump"
```

- No `docker exec`, no local files
- Dump streams directly into S3
- `$PGHOST` is the ECS Service Discovery DNS name of the Postgres task

---

### 2. Replace Host Crontab → EventBridge Scheduler

EventBridge Scheduler replaces `crontab` entries one-for-one. The schedule triggers
the backup ECS task with an environment variable override for the mode.

```
# Current crontab:
30 3 * * *  bash scripts/backup/daily_dump.sh --marts-only
30 1 * * 0  bash scripts/backup/weekly_basebackup.sh

# EventBridge equivalent:
cron(30 3 * * ? *)    → ECS backup task, MODE=marts-only
cron(30 1 ? * SUN *)  → ECS backup task, MODE=full
```

The `MODE` value is passed as a container environment variable override in the
`RunTask` call from EventBridge — same concept as the `$1` positional argument today.

---

### 3. Replace `weekly_basebackup.sh` → Full Dump to S3 or pgBackRest

`pg_basebackup` with `docker cp` relies on the container filesystem and cannot be
used in ECS without significant complexity. Two options:

**Option A — Weekly full `pg_dump` to S3 (simpler, recommended for this workload):**

Stream a full `pg_dump --format=tar` directly to S3. Suitable for a warehouse with
bulk loads (not high-frequency OLTP). Fargate tasks have no timeout cap on runtime.

**Option B — pgBackRest with S3 repository (production-grade):**

pgBackRest handles incremental physical backups, WAL archiving, retention, and restore
natively against S3. Requires adding pgBackRest to the Postgres container image and
configuring `postgresql.conf`:

```ini
# postgresql.conf additions for pgBackRest:
archive_mode = on
archive_command = 'pgbackrest --stanza=warehouse archive-push %p'
```

```ini
# /etc/pgbackrest/pgbackrest.conf:
[warehouse]
pg1-path=/var/lib/postgresql/data/pgdata

[global]
repo1-type=s3
repo1-s3-bucket=your-backup-bucket
repo1-s3-region=us-east-1
repo1-path=/pgbackrest
repo1-retention-full=2
```

For this warehouse workload, **Option A is sufficient** unless point-in-time recovery
(PITR) between weekly snapshots is required.

---

### 4. Replace `.env` Credentials → AWS Secrets Manager

Scripts currently source `.env` for `POSTGRES_PASSWORD`. On ECS, credentials are
injected by the ECS agent via Secrets Manager or SSM Parameter Store.

```json
// ECS Task Definition — containerDefinitions[].secrets:
[
  {
    "name": "POSTGRES_PASSWORD",
    "valueFrom": "arn:aws:secretsmanager:region:account:secret:pg-warehouse-password"
  },
  {
    "name": "BACKUP_BUCKET",
    "valueFrom": "arn:aws:ssm:region:account:parameter/warehouse/backup-bucket"
  }
]
```

The ECS agent injects these as environment variables at task startup. The existing
scripts already read `$POSTGRES_PASSWORD` and `$BACKUP_BUCKET` — **no script changes
needed for credential access**.

---

### 5. Replace Local `backup_log` Write → Keep It (No Changes Needed)

The `backup_log` INSERT uses a plain `psql` TCP connection. This works identically
from the backup ECS task connecting to the Postgres service endpoint. No changes needed.

---

### 6. Retire `offsite_sync.sh`

`offsite_sync.sh` exists solely to push local dumps to S3 after the fact.
Since dumps now pipe directly to S3, `offsite_sync.sh` is no longer needed.
S3 Lifecycle Policies replace the local `find ... -mtime +7 -delete` rotation logic.

```json
// S3 Lifecycle Policy on the backup bucket:
{
  "Rules": [{
    "Filter": { "Prefix": "postgres-dr/dumps/daily/" },
    "Expiration": { "Days": 7 },
    "Status": "Enabled"
  }, {
    "Filter": { "Prefix": "postgres-dr/dumps/weekly/" },
    "Expiration": { "Days": 14 },
    "Status": "Enabled"
  }]
}
```

---

## What Changes vs. What Stays the Same

| Component | Current | ECS |
|---|---|---|
| `pg_dump` invocation | `docker exec ... pg_dump` | Direct `pg_dump --host=$PGHOST` |
| Output destination | Local `backups/` directory | Pipe to `aws s3 cp -` |
| Scheduling | Host `crontab` | EventBridge Scheduler → ECS Task |
| Credentials | `.env` file | Secrets Manager → env vars |
| `pg_basebackup` | `docker exec` + `docker cp` | `pg_dump --format=tar` to S3 or pgBackRest |
| Offsite sync | `offsite_sync.sh` (aws s3 sync) | Eliminated — dumps go directly to S3 |
| `backup_log` INSERT | `docker exec psql` | Direct `psql --host=$PGHOST` |
| WAL archiving | Local WAL archive dir | `archive_command` → S3 |
| Retention/rotation | `find ... -mtime +7 -delete` | S3 Lifecycle Policy |

---

## IAM Policy for the Backup ECS Task Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BackupBucketAccess",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::your-backup-bucket",
        "arn:aws:s3:::your-backup-bucket/postgres-dr/*"
      ]
    },
    {
      "Sid": "SecretsAccess",
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:*:*:secret:pg-warehouse-*"
    },
    {
      "Sid": "SSMAccess",
      "Effect": "Allow",
      "Action": ["ssm:GetParameters"],
      "Resource": "arn:aws:ssm:*:*:parameter/warehouse/*"
    }
  ]
}
```

---

## Decision Point: RDS vs Self-Managed ECS Postgres

Before building this infrastructure, consider:

- **RDS / Aurora PostgreSQL** — AWS manages automated backups, PITR, snapshot
  retention, and failover. All 5 backup scripts become unnecessary. The trade-off
  is less control over `postgresql.conf`, extensions, and Postgres version timing.

- **Self-managed on ECS** — Retains full control over configuration, extensions,
  and the data model setup in `init/`. Requires owning the backup infrastructure
  described in this document.

For a production warehouse with SLA requirements and a small ops team, RDS is
the lower-risk path. For full control over the Postgres environment (custom
`postgresql.conf`, specific extensions, TPC-DS tuning), self-managed ECS is viable
with the backup plan above.

---

## Implementation Order

1. Create S3 backup bucket with Lifecycle Policies
2. Store credentials in Secrets Manager / SSM
3. Create Postgres ECS Task Definition + Service with Service Discovery
4. Rewrite `daily_dump.sh` for direct TCP + S3 pipe (remove `docker exec`)
5. Create backup ECS Task Definition using the new script
6. Configure EventBridge Scheduler rules for daily and weekly triggers
7. Set up IAM roles for both task definitions
8. Test backup task manually via `aws ecs run-task`
9. Verify `backup_log` writes succeed from the backup task
10. Decide on Option A vs Option B for physical backups and implement accordingly
