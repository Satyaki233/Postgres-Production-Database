# Postgres Production Database

A Dockerized PostgreSQL 16 production database setup with the `pg_uuidv7` extension, hardened access controls, and a two-tier role system for a data warehouse.

---

## Overview

This repo provisions a self-contained, production-ready PostgreSQL 16 instance using Docker Compose. Key design decisions:

- **pg_uuidv7 extension** built from source for time-ordered UUID primary keys
- **Port bound to `127.0.0.1` only** — not exposed to the network
- **SCRAM-SHA-256 authentication** instead of the default MD5
- **Public schema locked down** — no default open access
- **Two roles** (`warehouse_developer`, `warehouse_analyst`) with auto-grant on new schemas

---

## Project Structure

```
.
├── Dockerfile                     # Multi-stage build: compiles pg_uuidv7, then packages it into postgres:16
├── docker-compose.yml             # Service definition, volumes, networking, healthcheck
├── .env                           # Secrets (gitignored) — DB name, user, password
├── .gitignore
├── init/
│   ├── 01_restrict_access.sh      # Locks down PUBLIC access; runs first on container init
│   └── 02_roles_setup.sql         # Creates warehouse roles and example users; runs second
└── scripts/
    └── roles.sql                  # Reference copy of the roles SQL (not auto-executed)
```

---

## Prerequisites

- Docker and Docker Compose v2
- No local PostgreSQL needed — everything runs inside the container

---

## Configuration

Copy `.env` and fill in your values (never commit this file):

```env
POSTGRES_DB=your_database_name
POSTGRES_USER=your_superuser_name
POSTGRES_PASSWORD=your_strong_password
```

The `.gitignore` already excludes `.env`.

---

## Quick Start

```bash
# Build the image and start the container
docker compose up -d

# Check health
docker compose ps

# Connect (port 5433 on localhost)
psql -h 127.0.0.1 -p 5433 -U <POSTGRES_USER> -d <POSTGRES_DB>
```

---

## Container Details

| Setting | Value |
|---|---|
| Base image | `postgres:16` (Debian) |
| Container name | `postgres_production` |
| Host port | `127.0.0.1:5433` |
| Internal port | `5432` |
| Data volume | `postgres_data` (named Docker volume) |
| Restart policy | `unless-stopped` |
| Auth method | `scram-sha-256` |
| Log driver | `json-file` (50 MB × 5 files) |
| Network | `db_internal` (bridge, isolated) |

### Healthcheck

```bash
pg_isready -U <POSTGRES_USER> -d <POSTGRES_DB>
# interval: 10s | timeout: 5s | retries: 5 | start_period: 30s
```

---

## Initialization Scripts

Files inside `./init/` are mounted to `/docker-entrypoint-initdb.d/` and run **once**, in filename order, the first time the container starts (i.e., when the data volume is empty).

### `01_restrict_access.sh` — Access Hardening

Runs as the superuser and does three things:

1. Elevates `POSTGRES_USER` to `SUPERUSER` with `CREATEROLE` and `CREATEDB`
2. Revokes `ALL` on the database and `public` schema from `PUBLIC` (closes the default open door)
3. Re-grants full access exclusively to `POSTGRES_USER`

### `02_roles_setup.sql` — Role & User Provisioning

Creates two roles and an event trigger (see [Role System](#role-system) below), then creates example users.

---

## Role System

### `warehouse_developer`

Full read/write access — intended for engineers and backend services.

| Privilege | Scope |
|---|---|
| `CONNECT`, `CREATE` | Database |
| `USAGE`, `CREATE`, `ALL` | Schema `public` (and any future schemas) |
| `ALL` | Tables, sequences, functions, procedures |
| Default privileges | Auto-applied to future objects in all schemas |

### `warehouse_analyst`

Read-only access — intended for analysts and BI tools.

| Privilege | Scope |
|---|---|
| `CONNECT` | Database |
| `USAGE`, `CREATE` | Schema `public` (and any future schemas) |
| `SELECT` | Tables, sequences |
| `EXECUTE` | Functions |
| `pg_read_all_stats`, `pg_stat_scan_tables`, `pg_monitor` | System monitoring |

### Auto-Grant on New Schemas

An **event trigger** (`auto_grant_on_new_schema`) fires on every `CREATE SCHEMA` DDL command and automatically grants the appropriate privileges to both roles on the new schema. No manual grants are needed when adding schemas.

---

## Adding Users

Connect as the superuser and run:

```sql
-- Developer
CREATE USER dev_alice WITH PASSWORD 'strongpassword';
GRANT warehouse_developer TO dev_alice;

-- Analyst
CREATE USER analyst_bob WITH PASSWORD 'strongpassword';
GRANT warehouse_analyst TO analyst_bob;
```

`scripts/roles.sql` is a reference copy of the role SQL you can re-run or adapt when provisioning additional users outside the init flow.

---

## Extension: pg_uuidv7

The `Dockerfile` uses a multi-stage build to compile [`pg_uuidv7`](https://github.com/fboulnois/pg_uuidv7) from source:

```
Stage 1 (builder): postgres:16 + build tools → compiles pg_uuidv7.so
Stage 2 (final):   postgres:16 → copies .so, .control, and SQL files
```

To enable it in your database:

```sql
CREATE EXTENSION pg_uuidv7;

-- Then use it:
SELECT uuid_generate_v7();
```

UUIDv7 is time-ordered, making it significantly more index-friendly than UUIDv4 for high-insert workloads.

---

## Connecting from an Application

```
Host:     127.0.0.1
Port:     5433
Database: <POSTGRES_DB>
User:     <your_role_user>
Password: <password>
SSL:      recommended (configure pg_hba.conf as needed)
```

Example connection string:

```
postgresql://dev_alice:strongpassword@127.0.0.1:5433/warehouse
```

---

## Known Issues

- `init/02_roles_setup.sql` line 95 grants `warehouse_analyst` to `analyst_jane` but the user created on line 93 is `analyst_satyaki` — this is a copy-paste error. The corrected version is in `scripts/roles.sql` (that line is commented out). Fix before running in production.

---

## Security Notes

- The port is bound to `127.0.0.1` only — to expose it further, you must explicitly change the compose file and understand the implications.
- `SCRAM-SHA-256` is enforced at `initdb` time via `POSTGRES_INITDB_ARGS`.
- The `PUBLIC` role has been stripped of all default privileges — every new user must be explicitly granted a role.
- Never commit `.env` to version control.
