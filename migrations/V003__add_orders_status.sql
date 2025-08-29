/*---
change_id: V003
title: Add order status column to Orders
ticket: EE-1234
risk: low
change_type: additive
backward_compatible: true
requires_backfill: false
owner: keith.williams@company.com
reviewers: ["staff.eng@company.com"]
rollout_plan: "Add nullable order_status column with default, dual-read for 1 release, then populate"
rollback_plan: "Set default value, then drop column in follow-up migration"
---*/

-- Add order status tracking
-- Note: Using 'order_status' instead of 'status' to avoid SQL Server reserved word issues
-- This is a safe additive change that adds a nullable column with a default value

-- Add order_status column with default value
ALTER TABLE dbo.Orders 
ADD order_status NVARCHAR(32) NULL 
CONSTRAINT DF_Orders_order_status DEFAULT ('pending');
GO

-- Add index for order_status queries
CREATE INDEX IX_Orders_order_status ON dbo.Orders(order_status);
GO
-- Add check constraint for valid order_status values
ALTER TABLE dbo.Orders 
ADD CONSTRAINT CK_Orders_order_status_valid 
CHECK (order_status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded'));
GO
-- Update existing orders to have 'pending' order_status if they don't have one
-- This is safe because we added the column as nullable with a default
UPDATE dbo.Orders 
SET order_status = 'pending'
WHERE order_status IS NULL;
GO
-- Add composite index for common queries
CREATE INDEX IX_Orders_UserID_OrderStatus ON dbo.Orders(user_id, order_status) INCLUDE (created_at, total_amount);
GO
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
GO
CREATE INDEX IX_OrderStatusHistory_OrderID ON dbo.OrderStatusHistory(order_id);
CREATE INDEX IX_OrderStatusHistory_ChangedAt ON dbo.OrderStatusHistory(changed_at);
GO