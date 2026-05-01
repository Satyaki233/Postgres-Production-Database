-- ==========================================
-- WAREHOUSE ROLES SETUP
-- Run as satyaki on the warehouse database
-- ==========================================


-- ==========================================
-- WAREHOUSE DEVELOPER
-- ==========================================
CREATE ROLE warehouse_developer;

GRANT CONNECT ON DATABASE warehouse TO warehouse_developer;
GRANT CREATE ON DATABASE warehouse TO warehouse_developer;

GRANT USAGE, CREATE ON SCHEMA public TO warehouse_developer;
GRANT ALL ON SCHEMA public TO warehouse_developer;

GRANT ALL ON ALL TABLES IN SCHEMA public TO warehouse_developer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO warehouse_developer;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO warehouse_developer;
GRANT ALL ON ALL PROCEDURES IN SCHEMA public TO warehouse_developer;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO warehouse_developer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO warehouse_developer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO warehouse_developer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO warehouse_developer;


-- ==========================================
-- WAREHOUSE ANALYST
-- ==========================================
CREATE ROLE warehouse_analyst;

GRANT CONNECT ON DATABASE warehouse TO warehouse_analyst;

GRANT USAGE, CREATE ON SCHEMA public TO warehouse_analyst;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO warehouse_analyst;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO warehouse_analyst;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO warehouse_analyst;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO warehouse_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO warehouse_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO warehouse_analyst;

GRANT pg_read_all_stats TO warehouse_analyst;
GRANT pg_stat_scan_tables TO warehouse_analyst;
GRANT pg_monitor TO warehouse_analyst;


-- ==========================================
-- AUTO GRANT ON FUTURE SCHEMAS
-- ==========================================
CREATE OR REPLACE FUNCTION grant_privileges_on_new_schema()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
DECLARE
  schema_name TEXT;
BEGIN
  FOR schema_name IN
    SELECT object_identity
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag = 'CREATE SCHEMA'
  LOOP
    EXECUTE format('GRANT USAGE, CREATE ON SCHEMA %I TO warehouse_developer', schema_name);
    EXECUTE format('GRANT ALL ON SCHEMA %I TO warehouse_developer', schema_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON TABLES TO warehouse_developer', schema_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON SEQUENCES TO warehouse_developer', schema_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON FUNCTIONS TO warehouse_developer', schema_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON ROUTINES TO warehouse_developer', schema_name);

    EXECUTE format('GRANT USAGE, CREATE ON SCHEMA %I TO warehouse_analyst', schema_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT ON TABLES TO warehouse_analyst', schema_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT ON SEQUENCES TO warehouse_analyst', schema_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT EXECUTE ON FUNCTIONS TO warehouse_analyst', schema_name);

  END LOOP;
END;
$$;

CREATE EVENT TRIGGER auto_grant_on_new_schema
ON ddl_command_end
WHEN TAG IN ('CREATE SCHEMA')
EXECUTE FUNCTION grant_privileges_on_new_schema();


-- ==========================================
-- EXAMPLE USERS (uncomment and edit to use)
-- ==========================================
CREATE USER dev_satyaki WITH PASSWORD 'devsatyaki';
GRANT warehouse_developer TO dev_satyaki;

-- CREATE USER analyst_jane WITH PASSWORD 'strongpassword';
-- GRANT warehouse_analyst TO analyst_jane;