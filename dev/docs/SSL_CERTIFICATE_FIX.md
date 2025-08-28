# SQL Server SSL Certificate Error Fix

## 🚨 The Error You're Seeing

```
Sqlcmd: Error: Microsoft ODBC Driver 18 for SQL Server : SSL Provider: 
[error:0A000086:SSL routines::certificate verify failed:self-signed certificate].
Sqlcmd: Error: Microsoft ODBC Driver 18 for SQL Server : Client unable to establish connection.
```

## 🔧 **Quick Fix**

This is caused by **ODBC Driver 18's stricter SSL requirements**. The solution is simple:

### ✅ **Already Fixed in docker-compose.yml**

The health check command now includes the `-C` parameter:
```yaml
healthcheck:
  test: [
    "CMD-SHELL",
    "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'DevPassword123!' -C -Q 'SELECT 1' -b -o /dev/null"
  ]
```

### 🔄 **Apply the Fix**

1. **Stop and restart the container:**
   ```bash
   docker compose stop sqlserver
   docker compose up -d sqlserver
   ```

2. **Wait 2-3 minutes** for SQL Server to fully start

3. **Check if it's now healthy:**
   ```bash
   docker ps  # Should show "healthy" status
   ```

## 📋 **What the `-C` Parameter Does**

The `-C` parameter tells `sqlcmd` to **trust the server certificate** even if it's self-signed.

- ❌ **Without `-C`**: ODBC Driver 18 rejects self-signed certificates
- ✅ **With `-C`**: ODBC Driver 18 trusts the certificate and connects

## 🔍 **Test It Manually**

Run this to test the health check yourself:
```bash
# This should work now (with -C parameter)
docker exec db-dev-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P DevPassword123! -C -Q "SELECT 1"

# This would fail (without -C parameter)
docker exec db-dev-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P DevPassword123! -Q "SELECT 1"
```

## 🌐 **Connection Strings Also Fixed**

All connection strings in the project already include `TrustServerCertificate=True`:

```
Server=localhost,1433;Initial Catalog=DevDB;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True
```

This is the connection string equivalent of the `-C` parameter.

## 🔧 **Alternative Solutions**

If `-C` parameter doesn't work for some reason:

### Option 1: Disable encryption entirely
```bash
# Add -N parameter to disable encryption
sqlcmd -S localhost -U sa -P DevPassword123! -N -Q "SELECT 1"
```

### Option 2: Use older ODBC driver
```yaml
# Change in docker-compose.yml to use older tools (not recommended)
test: "/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'DevPassword123!' -Q 'SELECT 1'"
```

### Option 3: Use SQL Server 2019 image
```yaml
# Change in docker-compose.yml
image: mcr.microsoft.com/mssql/server:2019-latest
```

## 🎯 **Why This Happens**

- **ODBC Driver 17**: More lenient with certificates
- **ODBC Driver 18**: Stricter SSL requirements by default
- **SQL Server containers**: Use self-signed certificates
- **Result**: Health checks fail with certificate errors

## ✅ **Verification**

After applying the fix, you should see:

```bash
$ docker ps
CONTAINER ID   IMAGE              PORTS                    STATUS
abc123def456   mssql/server:2022  0.0.0.0:1433->1433/tcp   Up 3 minutes (healthy)
                                                           ^^^^^^^^^ 
                                                           Should show "healthy"
```

## 🆘 **Still Not Working?**

If you're still getting SSL errors:

1. **Run the diagnostic script:**
   ```bash
   .\health-check-debug.ps1 -RunHealthCheck
   ```

2. **Check container logs:**
   ```bash
   docker compose logs sqlserver
   ```

3. **Try the nuclear option:**
   ```bash
   .\cleanup.ps1 -RemoveVolumes
   docker compose up -d sqlserver
   ```

The `-C` parameter fix resolves 99% of SSL certificate issues with SQL Server containers!
