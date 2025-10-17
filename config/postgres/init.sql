-- Initialize PostgreSQL database for n8n
-- This script runs automatically when the container starts for the first time

-- Set timezone
SET timezone = 'Europe/Warsaw';

-- Ensure the n8n user has proper permissions
-- The POSTGRES_USER environment variable should create this user, but let's ensure permissions
DO $$
BEGIN
    -- Grant necessary permissions to the n8n user
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'n8n') THEN
        -- Grant create privileges on the database
        EXECUTE 'GRANT CREATE ON DATABASE ' || current_database() || ' TO n8n';
        -- Grant usage on public schema
        GRANT USAGE ON SCHEMA public TO n8n;
        -- Grant create on public schema
        GRANT CREATE ON SCHEMA public TO n8n;
        RAISE NOTICE 'Permissions granted to n8n user';
    ELSE
        RAISE NOTICE 'n8n user not found, it should be created by POSTGRES_USER environment variable';
    END IF;
    
    RAISE NOTICE 'PostgreSQL initialized for homelab stack';
END $$;