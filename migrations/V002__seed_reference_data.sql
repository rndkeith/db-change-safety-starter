/*---
change_id: V002
title: Seed reference data
ticket: SETUP-002
risk: low
change_type: additive
backward_compatible: true
requires_backfill: false
owner: setup@company.com
reviewers: ["dba@company.com"]
rollout_plan: "Insert initial reference data for application"
rollback_plan: "Delete specific reference records by known IDs"
---*/

-- Seed initial reference data
-- This migration adds essential reference data for the application

-- Insert sample products (use MERGE for idempotency)
MERGE dbo.Products AS target
USING (VALUES 
    ('Sample Product 1', 'A sample product for testing', 19.99, 'SKU-001'),
    ('Sample Product 2', 'Another sample product', 29.99, 'SKU-002'),
    ('Sample Product 3', 'Premium sample product', 49.99, 'SKU-003')
) AS source (name, description, price, sku)
ON target.sku = source.sku
WHEN NOT MATCHED THEN
    INSERT (name, description, price, sku, created_at, updated_at, is_active)
    VALUES (source.name, source.description, source.price, source.sku, 
            SYSUTCDATETIME(), SYSUTCDATETIME(), 1);

-- Insert a test user (use MERGE for idempotency)
MERGE dbo.Users AS target
USING (VALUES 
    ('test@example.com', 'testuser', 'hashed_password_placeholder', 'Test', 'User')
) AS source (email, username, password_hash, first_name, last_name)
ON target.email = source.email
WHEN NOT MATCHED THEN
    INSERT (email, username, password_hash, first_name, last_name, created_at, updated_at, is_active)
    VALUES (source.email, source.username, source.password_hash, source.first_name, source.last_name,
            SYSUTCDATETIME(), SYSUTCDATETIME(), 1);

-- Insert initial health probe record
INSERT INTO dbo.HealthProbe (probe_type, ts)
VALUES ('initialization', SYSUTCDATETIME());

-- Add application configuration table
CREATE TABLE dbo.AppConfig (
    config_key NVARCHAR(100) NOT NULL PRIMARY KEY,
    config_value NVARCHAR(MAX) NOT NULL,
    description NVARCHAR(500),
    created_at DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME()
);

-- Seed initial configuration
MERGE dbo.AppConfig AS target
USING (VALUES 
    ('app_version', '1.0.0', 'Current application version'),
    ('maintenance_mode', 'false', 'Whether the application is in maintenance mode'),
    ('max_order_items', '50', 'Maximum number of items per order')
) AS source (config_key, config_value, description)
ON target.config_key = source.config_key
WHEN NOT MATCHED THEN
    INSERT (config_key, config_value, description, created_at, updated_at)
    VALUES (source.config_key, source.config_value, source.description, 
            SYSUTCDATETIME(), SYSUTCDATETIME());
