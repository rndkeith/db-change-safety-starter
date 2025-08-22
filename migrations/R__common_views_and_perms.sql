-- Repeatable migration for common views and permissions
-- This file is executed whenever it changes, so all operations must be idempotent

-- Drop and recreate views (idempotent approach)
IF OBJECT_ID('dbo.vw_OrderSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_OrderSummary;
GO

CREATE VIEW dbo.vw_OrderSummary
AS
SELECT 
    o.id,
    o.order_number,
    o.total_amount,
    o.status,
    o.created_at,
    u.email as customer_email,
    u.first_name + ' ' + u.last_name as customer_name,
    COUNT(oi.id) as item_count
FROM dbo.Orders o
INNER JOIN dbo.Users u ON o.user_id = u.id
LEFT JOIN dbo.OrderItems oi ON o.id = oi.order_id
WHERE o.is_active = 1 OR o.is_active IS NULL  -- Handle potential nullable field
GROUP BY o.id, o.order_number, o.total_amount, o.status, o.created_at, 
         u.email, u.first_name, u.last_name;
GO

-- Product catalog view
IF OBJECT_ID('dbo.vw_ProductCatalog', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ProductCatalog;
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
    COALESCE(order_stats.total_sold, 0) as total_sold,
    COALESCE(order_stats.revenue, 0) as total_revenue
FROM dbo.Products p
LEFT JOIN (
    SELECT 
        oi.product_id,
        SUM(oi.quantity) as total_sold,
        SUM(oi.total_price) as revenue
    FROM dbo.OrderItems oi
    INNER JOIN dbo.Orders o ON oi.order_id = o.id
    WHERE o.status NOT IN ('cancelled', 'refunded')
    GROUP BY oi.product_id
) order_stats ON p.id = order_stats.product_id
WHERE p.is_active = 1;
GO

-- Health check view
IF OBJECT_ID('dbo.vw_SystemHealth', 'V') IS NOT NULL
    DROP VIEW dbo.vw_SystemHealth;
GO

CREATE VIEW dbo.vw_SystemHealth
AS
SELECT 
    'database' as component,
    'healthy' as status,
    SYSUTCDATETIME() as check_time,
    (SELECT COUNT(*) FROM dbo.Users WHERE is_active = 1) as active_users,
    (SELECT COUNT(*) FROM dbo.Products WHERE is_active = 1) as active_products,
    (SELECT COUNT(*) FROM dbo.Orders WHERE created_at >= DATEADD(day, -1, SYSUTCDATETIME())) as orders_last_24h;
GO

-- Application user permissions (idempotent)
-- These would typically be applied by a DBA with appropriate privileges

-- Create application roles if they don't exist
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'app_reader' AND type = 'R')
    CREATE ROLE app_reader;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'app_writer' AND type = 'R')
    CREATE ROLE app_writer;

-- Grant permissions to roles
-- Reader permissions
GRANT SELECT ON dbo.Users TO app_reader;
GRANT SELECT ON dbo.Products TO app_reader;
GRANT SELECT ON dbo.Orders TO app_reader;
GRANT SELECT ON dbo.OrderItems TO app_reader;
GRANT SELECT ON dbo.OrderStatusHistory TO app_reader;
GRANT SELECT ON dbo.AppConfig TO app_reader;
GRANT SELECT ON dbo.vw_OrderSummary TO app_reader;
GRANT SELECT ON dbo.vw_ProductCatalog TO app_reader;
GRANT SELECT ON dbo.vw_SystemHealth TO app_reader;

-- Writer permissions (includes reader)
GRANT SELECT, INSERT, UPDATE ON dbo.Users TO app_writer;
GRANT SELECT, INSERT, UPDATE ON dbo.Products TO app_writer;
GRANT SELECT, INSERT, UPDATE ON dbo.Orders TO app_writer;
GRANT SELECT, INSERT, UPDATE ON dbo.OrderItems TO app_writer;
GRANT SELECT, INSERT, UPDATE ON dbo.OrderStatusHistory TO app_writer;
GRANT SELECT, INSERT, UPDATE ON dbo.AppConfig TO app_writer;
GRANT INSERT ON dbo.HealthProbe TO app_writer;

-- Stored procedures for common operations (idempotent)
IF OBJECT_ID('dbo.sp_UpdateOrderStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_UpdateOrderStatus;
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
    SELECT @OldStatus = status 
    FROM dbo.Orders 
    WHERE id = @OrderId;
    
    IF @OldStatus IS NULL
    BEGIN
        THROW 50000, 'Order not found', 1;
        RETURN;
    END
    
    -- Update order status
    UPDATE dbo.Orders 
    SET status = @NewStatus, updated_at = SYSUTCDATETIME()
    WHERE id = @OrderId;
    
    -- Log status change
    INSERT INTO dbo.OrderStatusHistory (order_id, old_status, new_status, changed_by, reason)
    VALUES (@OrderId, @OldStatus, @NewStatus, @ChangedBy, @Reason);
END;
GO

-- Grant execute permission on stored procedures
GRANT EXECUTE ON dbo.sp_UpdateOrderStatus TO app_writer;
