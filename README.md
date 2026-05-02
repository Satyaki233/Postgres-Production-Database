# PostgreSQL Data Warehouse

A full-scale, Dockerized data warehouse built on PostgreSQL 16, pre-loaded with the TPC-DS benchmark dataset (SF 10, ~10 GB) and a complete monitoring + connection-pooling stack.

---

## Architecture

```
Clients
  │
  ▼
PgBouncer :5432          ← session-mode connection pool (200 max clients)
  │
  ▼
PostgreSQL :5433         ← OLAP-tuned (16 GB RAM / 4 cores)
  ├── raw/               ← TPC-DS data as-loaded (24 tables, ~50M rows)
  ├── staging/           ← cleaned, typed, null-safe copies
  └── marts/             ← partitioned fact tables + conformed dimensions

postgres_exporter → Prometheus :9090 → Grafana :3000
```

**What's included:**

| Component                 | Purpose                                           |
| ------------------------- | ------------------------------------------------- |
| PostgreSQL 16 + pg_uuidv7 | Core database + time-ordered UUIDs                |
| pg_partman                | Range partition management on fact tables         |
| pg_cron                   | Scheduled VACUUM + partition maintenance          |
| pg_stat_statements        | Query performance tracking                        |
| tablefunc / cube          | Pivot tables, OLAP-style queries                  |
| PgBouncer (session mode)  | Connection pooling — safe for analytics workloads |
| postgres_exporter         | Exposes PostgreSQL metrics to Prometheus          |
| Prometheus                | Metrics store (30-day retention)                  |
| Grafana                   | Pre-provisioned PostgreSQL dashboard              |

---

## Project Structure

```
.
├── Dockerfile                              # Multi-stage: builds pg_uuidv7 + installs pg_partman, pg_cron
├── docker-compose.yml                      # 5-service stack
├── postgresql.conf                         # OLAP tuning (16 GB RAM / 4 cores)
├── .env                                    # Secrets (gitignored)
├── .gitignore
│
├── init/                                   # Auto-run on first container start, in order
│   ├── 01_restrict_access.sh               # Locks down PUBLIC; elevates superuser
│   ├── 02_roles_setup.sql                  # Roles, schemas (raw/staging/marts), extensions
│   └── 03_cron_jobs.sql                    # pg_cron: nightly VACUUM + weekly partition maintenance
│
├── tpcds/
│   ├── generate.sh                         # Builds dsdgen, generates SF10 .dat files → data/
│   ├── load.sh                             # Bulk-loads .dat files into raw schema
│   └── schema/
│       └── tpcds.sql                       # 24-table TPC-DS DDL (raw schema, no constraints)
│
├── staging/
│   └── transform.sql                       # raw → staging: trims strings, filters null PKs
│
├── marts/
│   ├── create_marts.sql                    # Partitioned facts + conformed dimensions
│   └── indexes.sql                         # B-tree indexes + VACUUM ANALYZE
│
├── prometheus/
│   └── prometheus.yml
├── grafana/
│   └── provisioning/
│       ├── datasources/prometheus.yml
│       └── dashboards/
│           ├── dashboards.yml
│           └── postgres.json               # Grafana dashboard ID 9628 (auto-provisioned)
└── scripts/
    └── roles.sql                           # Reference copy of roles SQL
```

---

## Prerequisites

- Docker and Docker Compose v2
- ~35 GB free disk (10 GB data + 3× overhead for indexes/WAL + monitoring volumes)
- `git` and C build tools (only needed on the host to run `generate.sh`)

---

## Configuration

Create `.env` with your credentials (already gitignored):

```env
POSTGRES_DB=warehouse
POSTGRES_USER=your_superuser
POSTGRES_PASSWORD=strong_password
GRAFANA_PASSWORD=your_grafana_password
```

---

## Quick Start

```bash
# 1. Build images and start the stack
docker compose up -d

# 2. Confirm all services are healthy
docker compose ps
```

---

## Loading TPC-DS Data (One-Time)

```bash
# Step 1 — Generate 10 GB of data (~20-30 min)
bash tpcds/generate.sh

# Step 2 — Create raw schema tables
psql -h 127.0.0.1 -p 5434 -U $POSTGRES_USER -d $POSTGRES_DB \
     -f tpcds/schema/tpcds.sql

# Step 3 — Bulk load into raw schema (~20-40 min)
bash tpcds/load.sh

# Step 4 — Clean and copy into staging
psql -h 127.0.0.1 -p 5434 -U $POSTGRES_USER -d $POSTGRES_DB \
     -f staging/transform.sql

# Step 5 — Build partitioned facts + dimensions
psql -h 127.0.0.1 -p 5434 -U $POSTGRES_USER -d $POSTGRES_DB \
     -f marts/create_marts.sql

# Step 6 — Add indexes and run VACUUM ANALYZE
psql -h 127.0.0.1 -p 5434 -U $POSTGRES_USER -d $POSTGRES_DB \
     -f marts/indexes.sql
```

Total time: approximately 1–1.5 hours on a typical laptop.

---

## Service Ports

| Service    | Host             | Purpose                                  |
| ---------- | ---------------- | ---------------------------------------- |
| PgBouncer  | `127.0.0.1:6432` | Main client entry point                  |
| PostgreSQL | `127.0.0.1:5434` | Admin / init scripts only                |
| Grafana    | `127.0.0.1:3000` | Dashboards (admin / `$GRAFANA_PASSWORD`) |
| Prometheus | `127.0.0.1:9090` | Metrics query UI                         |

---

## Connecting

Via PgBouncer (normal use):

```
postgresql://user:password@127.0.0.1:6432/warehouse
```

Direct PostgreSQL (admin only):

```
postgresql://user:password@127.0.0.1:5434/warehouse
```

---

## Data Model

### Raw Schema (24 TPC-DS tables)

Exact copy of generated data. No constraints. Used only as a landing zone.

**Fact tables:** `store_sales` (~28M rows), `web_sales` (~7M), `catalog_sales` (~14M), `store_returns`, `web_returns`, `catalog_returns`, `inventory`

**Dimension tables:** `date_dim`, `time_dim`, `customer`, `customer_demographics`, `customer_address`, `item`, `store`, `promotion`, `household_demographics`, `web_site`, `web_page`, `warehouse`, `ship_mode`, `reason`, `income_band`, `call_center`, `catalog_page`

### Staging Schema

Cleaned copies of all 24 raw tables. Trailing whitespace trimmed, empty strings coerced to NULL, rows with null mandatory keys filtered out.

### Marts Schema

Production-ready layer for analytics:

| Table                | Type               | Rows (SF10) | Partitioned by          |
| -------------------- | ------------------ | ----------- | ----------------------- |
| `fact_store_sales`   | Fact               | ~28M        | `ss_sold_date_sk` RANGE |
| `fact_web_sales`     | Fact               | ~7M         | `ws_sold_date_sk` RANGE |
| `fact_catalog_sales` | Fact               | ~14M        | `cs_sold_date_sk` RANGE |
| `dim_date`           | Dimension          | 73,049      | —                       |
| `dim_customer`       | Dimension (denorm) | ~2M         | —                       |
| `dim_item`           | Dimension          | ~204K       | —                       |
| `dim_store`          | Dimension          | ~402        | —                       |
| `dim_promotion`      | Dimension          | ~1K         | —                       |

---

## Role System

| Role                  | Access                                                 |
| --------------------- | ------------------------------------------------------ |
| `warehouse_developer` | Full read/write on `raw`, `staging`, `marts`, `public` |
| `warehouse_analyst`   | Read-only on all schemas; can monitor via `pg_monitor` |

Adding a user:

```sql
CREATE USER alice WITH PASSWORD 'strongpassword';
GRANT warehouse_developer TO alice;   -- or warehouse_analyst
```

---

## Monitoring

Open Grafana: `http://localhost:3000` (login: `admin` / `$GRAFANA_PASSWORD`)

The **PostgreSQL Database** dashboard (auto-provisioned) shows:

- Active / idle sessions and connection counts
- Cache hit rate
- Transactions per second (commits + rollbacks)
- Temp file writes (signals insufficient `work_mem`)
- Checkpoint timing
- Conflicts and deadlocks
- PostgreSQL settings (shared_buffers, work_mem, etc.)

---

## Scheduled Maintenance

`pg_cron` runs automatically inside the warehouse database:

| Schedule      | Job                                                      |
| ------------- | -------------------------------------------------------- |
| Daily 2:00am  | `VACUUM ANALYZE` on all three fact tables                |
| Daily 2:30am  | `VACUUM ANALYZE` on dimension tables                     |
| Sunday 1:00am | `pg_partman` run_maintenance (creates future partitions) |
| Sunday 3:00am | `pg_stat_statements` reset                               |

---

## OLAP Tuning (postgresql.conf)

Configured for 16 GB RAM / 4 cores:

| Setting                | Value  | Why                                         |
| ---------------------- | ------ | ------------------------------------------- |
| `shared_buffers`       | 4 GB   | 25% of RAM                                  |
| `work_mem`             | 256 MB | Per sort/hash — large for analytics queries |
| `effective_cache_size` | 12 GB  | 75% of RAM — guides planner                 |
| `max_parallel_workers` | 4      | One per core                                |
| `random_page_cost`     | 1.1    | SSD-optimized                               |
| `max_connections`      | 50     | PgBouncer is in front                       |

---

## Security Notes

- Port `5433` (PostgreSQL direct) is bound to `127.0.0.1` only — not exposed to the network
- Port `5432` (PgBouncer) is also localhost-only
- SCRAM-SHA-256 enforced for all PostgreSQL host connections
- `PUBLIC` role has no default privileges
- `.env` is gitignored; `data/` and `tpcds/tpcds-kit/` are gitignored

---

## Known Issues

- `init/02_roles_setup.sql` line 95 in the original had a bug (`GRANT warehouse_analyst TO analyst_jane` instead of `analyst_satyaki`). This is fixed — the grant line is now commented out as an example.
