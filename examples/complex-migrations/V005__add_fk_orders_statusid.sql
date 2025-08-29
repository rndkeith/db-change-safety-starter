/*---
change_id: V005
title: Add foreign key constraint for Orders.StatusId -> Statuses.Id
ticket: EE-1234
risk: low
change_type: additive
backward_compatible: true
requires_backfill: false
owner: keith.williams@company.com
reviewers: ["staff.eng@company.com"]
rollout_plan: "Add FK constraint to ensure referential integrity. StatusId remains nullable to avoid blocking deployment; make NOT NULL in a follow-up migration once application is updated."
rollback_plan: "Drop FK constraint if necessary."
---*/

-- Add foreign key constraint (StatusId remains nullable)

-- Set default for StatusId to 'pending' status
ALTER TABLE dbo.Orders
ADD CONSTRAINT DF_Orders_StatusId DEFAULT (1) FOR StatusId;
GO

ALTER TABLE dbo.Orders
ADD CONSTRAINT FK_Orders_Statuses FOREIGN KEY (StatusId) REFERENCES dbo.Statuses(Id);
GO
