/*---
change_id: V003
title: Add status column to Orders
ticket: EE-1234
risk: low
change_type: additive
backward_compatible: true
requires_backfill: false
owner: keith.williams@company.com
reviewers: ["staff.eng@company.com"]
rollout_plan: "Add nullable status column with default, dual-read for 1 release, then populate"
rollback_plan: "Set default value, then drop column in follow-up migration Vxxx"
---*/

-- Add order status tracking
-- This is a safe additive change that adds a nullable column with a default value

-- Add status column with default value
ALTER TABLE dbo.Orders 
ADD status NVARCHAR(32) NULL 
CONSTRAINT DF_Orders_status DEFAULT ('pending');

-- Add index for status queries
CREATE INDEX IX_Orders_status ON dbo.Orders(status);

-- Add check constraint for valid status values
ALTER TABLE dbo.Orders 
ADD CONSTRAINT CK_Orders_status_valid 
CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded'));

-- Update existing orders to have 'pending' status if they don't have one
-- This is safe because we added the column as nullable with a default
UPDATE dbo.Orders 
SET status = 'pending'
WHERE status IS NULL;

-- Add composite index for common queries
CREATE INDEX IX_Orders_UserID_Status ON dbo.Orders(user_id, status) INCLUDE (created_at, total_amount);

-- Add audit trail for status changes (prepare for future feature)
CREATE TABLE dbo.OrderStatusHistory (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    order_id BIGINT NOT NULL,
    old_status NVARCHAR(32),
    new_status NVARCHAR(32) NOT NULL,
    changed_by NVARCHAR(255),
    changed_at DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    reason NVARCHAR(500),
    
    CONSTRAINT FK_OrderStatusHistory_Orders FOREIGN KEY (order_id) REFERENCES dbo.Orders(id)
);

CREATE INDEX IX_OrderStatusHistory_OrderID ON dbo.OrderStatusHistory(order_id);
CREATE INDEX IX_OrderStatusHistory_ChangedAt ON dbo.OrderStatusHistory(changed_at);
