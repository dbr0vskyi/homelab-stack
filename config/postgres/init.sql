-- Initialize PostgreSQL database for n8n
-- This script runs automatically when the container starts for the first time

-- Create additional schemas if needed
-- CREATE SCHEMA IF NOT EXISTS workflows;

-- Set timezone
SET timezone = 'Europe/Warsaw';

-- Create indexes for better performance (n8n will create tables)
-- These will be applied after n8n creates its tables
DO $$
BEGIN
    -- Add any custom initialization here
    RAISE NOTICE 'PostgreSQL initialized for homelab stack';
END $$;