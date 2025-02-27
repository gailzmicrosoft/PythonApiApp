-- Grant access to the database
GRANT CONNECT ON DATABASE sample_database TO sample_user_name;

-- Grant access to the schema
GRANT USAGE ON SCHEMA public TO sample_user_name;

-- Grant permissions on all tables in the schema
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sample_user_name;

-- Ensure the user has permissions on any future tables created in the schema
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sample_user_name;


--#######################################################################################
-- Grant Permissions to User on Database and Schema
--#######################################################################################

-- Grant USAGE and CREATE privileges on the public schema
GRANT USAGE, CREATE ON SCHEMA public TO sample_user_name;

-- Grant INSERT, UPDATE, DELETE, and SELECT privileges on all tables in the public schema
GRANT INSERT, UPDATE, DELETE, SELECT ON ALL TABLES IN SCHEMA public TO sample_user_name;

-- Grant USAGE and SELECT privileges on all sequences in the public schema
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sample_user_name;

-- Ensure future tables and sequences will have the same privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT INSERT, UPDATE, DELETE, SELECT ON TABLES TO sample_user_name;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO sample_user_name;
