/*---
change_id: V003
title: Create Statuses domain table and seed canonical rows
ticket: EE-1234
risk: low
change_type: additive
backward_compatible: true
requires_backfill: true
owner: keith.williams@company.com
reviewers: ["staff.eng@company.com"]
rollout_plan: "Create Statuses lookup table and seed canonical status codes. This is additive and safe to apply online."
rollback_plan: "Drop the Statuses table if required (only safe if nothing depends on it)."
---*/

-- Create a canonical Statuses table to normalize order status values
CREATE TABLE dbo.Statuses (
    Id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Code NVARCHAR(50) NOT NULL UNIQUE,
    DisplayName NVARCHAR(100) NOT NULL
);
GO

-- Seed canonical statuses
INSERT INTO dbo.Statuses (Code, DisplayName) VALUES
('pending','Pending'),
('processing','Processing'),
('shipped','Shipped'),
('delivered','Delivered'),
('cancelled','Cancelled'),
('refunded','Refunded');
GO

-- Helpful index for lookups by Code
CREATE UNIQUE INDEX IX_Statuses_Code ON dbo.Statuses(Code);
GO
