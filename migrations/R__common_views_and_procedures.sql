-- Repeatable migration for common views and procedures
-- This file is executed whenever it changes, so all operations must be idempotent

-- Drop and recreate views (idempotent approach)
DROP VIEW IF EXISTS dbo.vw_OrderSummary;
GO

CREATE VIEW dbo.vw_OrderSummary
AS
SELECT 
    o.id,
    o.order_number,
    o.total_amount,
    ISNULL(o.order_status, 'pending') as order_status,
    o.created_at,
    u.email as customer_email,
    u.first_name + ' ' + u.last_name as customer_name,
    COUNT(oi.id) as item_count
FROM dbo.Orders o
INNER JOIN dbo.Users u ON o.user_id = u.id
LEFT JOIN dbo.OrderItems oi ON o.id = oi.order_id
GROUP BY o.id, o.order_number, o.total_amount, o.order_status, o.created_at, 
         u.email, u.first_name, u.last_name;
GO

-- Product catalog view
DROP VIEW IF EXISTS dbo.vw_ProductCatalog;
GO

CREATE VIEW dbo.vw_ProductCatalog
AS
SELECT 
    p.id,
    p.name,
    p.description,
    p.price,
    p.sku,
    p.created_at,
    ISNULL(order_stats.total_sold, 0) as total_sold,
    ISNULL(order_stats.revenue, 0) as total_revenue
FROM dbo.Products p
LEFT JOIN (
    SELECT 
        oi.product_id,
        SUM(oi.quantity) as total_sold,
        SUM(oi.total_price) as revenue
    FROM dbo.OrderItems oi
    INNER JOIN dbo.Orders o ON oi.order_id = o.id
    WHERE ISNULL(o.order_status, 'pending') NOT IN ('cancelled', 'refunded')
    GROUP BY oi.product_id
) order_stats ON p.id = order_stats.product_id
WHERE p.is_active = 1;
GO

-- Health check view
DROP VIEW IF EXISTS dbo.vw_SystemHealth;
GO

CREATE VIEW dbo.vw_SystemHealth
AS
SELECT 
    'database' as component,
    'healthy' as health_status,
    SYSUTCDATETIME() as check_time,
    (SELECT COUNT(*) FROM dbo.Users WHERE is_active = 1) as active_users,
    (SELECT COUNT(*) FROM dbo.Products WHERE is_active = 1) as active_products,
    (SELECT COUNT(*) FROM dbo.Orders WHERE created_at >= DATEADD(day, -1, SYSUTCDATETIME())) as orders_last_24h;
GO

-- Simple stored procedure for updating order status
DROP PROCEDURE IF EXISTS dbo.sp_UpdateOrderStatus;
GO

CREATE PROCEDURE dbo.sp_UpdateOrderStatus
    @OrderId BIGINT,
    @NewStatus NVARCHAR(32),
    @ChangedBy NVARCHAR(255) = NULL,
    @Reason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @OldStatus NVARCHAR(32);
    
    -- Get current status
    SELECT @OldStatus = ISNULL(order_status, 'pending')
    FROM dbo.Orders 
    WHERE id = @OrderId;
    
    IF @@ROWCOUNT = 0
    BEGIN
        THROW 50000, 'Order not found', 1;
        RETURN;
    END
    
    -- Update order status
    UPDATE dbo.Orders 
    SET order_status = @NewStatus, updated_at = SYSUTCDATETIME()
    WHERE id = @OrderId;
    
    -- Log status change if history table exists
    IF OBJECT_ID('dbo.OrderStatusHistory', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.OrderStatusHistory (order_id, old_status, new_status, changed_by, reason)
        VALUES (@OrderId, @OldStatus, @NewStatus, @ChangedBy, @Reason);
    END
END;
GO