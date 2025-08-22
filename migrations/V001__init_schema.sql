/*---
change_id: V001
title: Initialize database schema
ticket: SETUP-001
risk: low
change_type: additive
backward_compatible: true
requires_backfill: false
owner: setup@company.com
reviewers: ["dba@company.com"]
rollout_plan: "Initial schema creation for new database"
rollback_plan: "Drop database and recreate (new system only)"
---*/

-- Initialize core application schema
-- This migration creates the foundational tables for the application

-- Create core tables
CREATE TABLE dbo.Users (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    email NVARCHAR(255) NOT NULL UNIQUE,
    username NVARCHAR(100) NOT NULL UNIQUE,
    password_hash NVARCHAR(255) NOT NULL,
    first_name NVARCHAR(100) NOT NULL,
    last_name NVARCHAR(100) NOT NULL,
    created_at DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    is_active BIT NOT NULL DEFAULT 1
);

CREATE TABLE dbo.Products (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX),
    price DECIMAL(10,2) NOT NULL,
    sku NVARCHAR(50) NOT NULL UNIQUE,
    created_at DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    is_active BIT NOT NULL DEFAULT 1
);

CREATE TABLE dbo.Orders (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id BIGINT NOT NULL,
    order_number NVARCHAR(50) NOT NULL UNIQUE,
    total_amount DECIMAL(10,2) NOT NULL,
    created_at DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    
    CONSTRAINT FK_Orders_Users FOREIGN KEY (user_id) REFERENCES dbo.Users(id)
);

CREATE TABLE dbo.OrderItems (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (order_id) REFERENCES dbo.Orders(id),
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (product_id) REFERENCES dbo.Products(id)
);

-- Create indexes for performance
CREATE INDEX IX_Users_Email ON dbo.Users(email);
CREATE INDEX IX_Users_Username ON dbo.Users(username);
CREATE INDEX IX_Products_SKU ON dbo.Products(sku);
CREATE INDEX IX_Orders_UserID ON dbo.Orders(user_id);
CREATE INDEX IX_Orders_OrderNumber ON dbo.Orders(order_number);
CREATE INDEX IX_OrderItems_OrderID ON dbo.OrderItems(order_id);
CREATE INDEX IX_OrderItems_ProductID ON dbo.OrderItems(product_id);

-- Create health probe table for monitoring
CREATE TABLE dbo.HealthProbe (
    id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    ts DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    probe_type NVARCHAR(50) NOT NULL DEFAULT 'general'
);

-- Add check constraints
ALTER TABLE dbo.Products ADD CONSTRAINT CK_Products_Price_Positive CHECK (price >= 0);
ALTER TABLE dbo.Orders ADD CONSTRAINT CK_Orders_Total_Positive CHECK (total_amount >= 0);
ALTER TABLE dbo.OrderItems ADD CONSTRAINT CK_OrderItems_Quantity_Positive CHECK (quantity > 0);
ALTER TABLE dbo.OrderItems ADD CONSTRAINT CK_OrderItems_UnitPrice_Positive CHECK (unit_price >= 0);
ALTER TABLE dbo.OrderItems ADD CONSTRAINT CK_OrderItems_TotalPrice_Positive CHECK (total_price >= 0);
