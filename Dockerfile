# Debian based
FROM postgres:16 AS builder

RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    postgresql-server-dev-16 \
    && git clone https://github.com/fboulnois/pg_uuidv7.git /tmp/pg_uuidv7 \
    && cd /tmp/pg_uuidv7 \
    && make PG_CONFIG=/usr/bin/pg_config

FROM postgres:16

RUN apt-get update && apt-get install -y \
    postgresql-16-partman \
    postgresql-16-cron \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/pg_uuidv7/pg_uuidv7.so /usr/lib/postgresql/16/lib/
COPY --from=builder /tmp/pg_uuidv7/pg_uuidv7.control /usr/share/postgresql/16/extension/
COPY --from=builder /tmp/pg_uuidv7/sql/ /usr/share/postgresql/16/extension/