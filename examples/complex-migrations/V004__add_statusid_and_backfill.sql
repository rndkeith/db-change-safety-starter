/*---
change_id: V004
title: Add StatusId column to Orders
ticket: EE-1234
risk: low
change_type: additive
backward_compatible: true
requires_backfill: false
owner: keith.williams@company.com
reviewers: ["staff.eng@company.com"]
rollout_plan: "Add nullable StatusId to Orders. No backfill required since legacy status column never existed."
rollback_plan: "Drop StatusId column if rolling back (only safe if application is not using it)."
---*/

-- Add nullable StatusId to orders
ALTER TABLE dbo.Orders
ADD StatusId INT NULL;
GO

-- Add index on StatusId to support queries
CREATE INDEX IX_Orders_StatusId ON dbo.Orders(StatusId) INCLUDE (created_at, total_amount);
GO
