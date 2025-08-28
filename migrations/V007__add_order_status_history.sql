/*---
change_id: V007
title: Add OrderStatusHistory table for tracking order status changes
ticket: EE-1234
risk: low
change_type: additive
backward_compatible: true
requires_backfill: false
owner: keith.williams@company.com
reviewers: ["staff.eng@company.com"]
rollout_plan: "Add OrderStatusHistory table to track status changes for orders. Safe to apply online."
rollback_plan: "Drop OrderStatusHistory table if rollback is required."
---*/

-- Create OrderStatusHistory table to track status changes
CREATE TABLE dbo.OrderStatusHistory (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    OrderId BIGINT NOT NULL,
    OldStatus NVARCHAR(50),
    NewStatus NVARCHAR(50) NOT NULL,
    ChangedBy NVARCHAR(255),
    ChangedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    Reason NVARCHAR(500),
    CONSTRAINT FK_OrderStatusHistory_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(Id)
);
GO

-- Indexes for efficient queries
CREATE INDEX IX_OrderStatusHistory_OrderId ON dbo.OrderStatusHistory(OrderId);
GO
CREATE INDEX IX_OrderStatusHistory_ChangedAt ON dbo.OrderStatusHistory(ChangedAt);
GO
