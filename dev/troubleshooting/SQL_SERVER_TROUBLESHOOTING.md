# SQL Server Container Troubleshooting Guide

## 🩺 Quick Diagnosis

Run the diagnostic script first:
```bash
.\diagnose-sqlserver.ps1           # Basic diagnosis
.\diagnose-sqlserver.ps1 -Fix      # Try auto-fix
.\diagnose-sqlserver.ps1 -Verbose  # Detailed output
```

## 🚨 Common Issues and Solutions

### SSL certificate error fix (ODBC Driver 18)

If you see errors like:

```
Sqlcmd: Error: Microsoft ODBC Driver 18 for SQL Server : SSL Provider:
[error:0A000086:SSL routines::certificate verify failed:self-signed certificate].
Sqlcmd: Error: Microsoft ODBC Driver 18 for SQL Server : Client unable to establish connection.
```

Cause: ODBC Driver 18 enforces certificate validation by default and the SQL Server container uses a self-signed certificate.

Fix: Trust the certificate with the -C flag (already applied in our health check) or use TrustServerCertificate=True in connection strings.

Manual tests:

```bash
# Works (trust server cert)
docker exec db-dev-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P DevPassword123! -C -Q "SELECT 1"

# Fails without -C (kept for illustration)
docker exec db-dev-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P DevPassword123! -Q "SELECT 1"
```

Connection string equivalent:

```
Server=localhost,1433;Initial Catalog=DevDB;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True
```

### Issue 1: Container starts but shows "unhealthy"

**Symptoms:**
- Container shows as "unhealthy" in `docker ps`
- Health check keeps failing

**Solutions:**

1. **Wait longer** - SQL Server needs 2-3 minutes to fully start:
   ```bash
   docker compose logs -f sqlserver
   # Look for "SQL Server is now ready for client connections"
   ```

2. **Check memory allocation**:
   - Ensure Docker Desktop has 4GB+ RAM allocated
   - On Windows: Docker Desktop → Settings → Resources → Memory

3. **Reset the container data**:
   ```bash
   docker compose stop sqlserver
   docker volume rm dev_sqlserver_data
   docker compose up -d sqlserver
   ```

### Issue 2: "Password validation failed" 

**Symptoms:**
- Container exits immediately
- Logs show password policy errors

**Solutions:**

1. **Check password requirements**:
   - At least 8 characters
   - Contains uppercase, lowercase, numbers, and symbols
   - Current password "DevPassword123!" should work

2. **Try alternative password**:
   ```bash
   # Edit docker-compose.yml, change to:
   SA_PASSWORD=MyStrong@Passw0rd
   ```

### Issue 3: Port 1433 already in use

**Symptoms:**
- "Port already allocated" error
- Cannot bind to port 1433

**Solutions:**

1. **Find what's using the port**:
   ```bash
   # Windows
   netstat -ano | findstr :1433
   
   # Kill the process using the port
   taskkill /PID <process_id> /F
   ```

2. **Use a different port**:
   ```bash
   # Edit docker-compose.yml:
   ports:
     - "14330:1433"  # Use port 14330 instead
   ```

### Issue 4: Insufficient memory

**Symptoms:**
- Container starts then stops
- "Out of memory" errors in logs
- Very slow startup

**Solutions:**

1. **Increase available memory**:
   - Windows (WSL 2 backend): Configure memory in `%UserProfile%\.wslconfig` (Docker Desktop sliders are ignored with WSL 2)
   - Windows (Hyper-V/legacy): Docker Desktop → Settings → Resources
   - Recommended: 4GB minimum, 8GB preferred

   Windows WSL 2 example (`%UserProfile%\.wslconfig`):
   ```ini
   [wsl2]
   memory=6GB         # limit memory
   processors=4       # limit CPU
   swap=2GB           # optional swap size (set 0 to disable)
   ```

   Apply changes (PowerShell):
   ```powershell
   wsl.exe --shutdown   # stops all WSL distros, including docker-desktop
   # then restart Docker Desktop
   ```

2. **Reduce SQL Server memory usage**:
   ```yaml
   # In docker-compose.yml, already added:
   environment:
     - MSSQL_MEMORY_LIMIT_MB=2048
   ```

### Issue 5: Platform/Architecture issues

**Symptoms:**
- "no matching manifest" errors  
- Container won't start on ARM/Apple Silicon

**Solutions:**

1. **Use platform-specific image**:
   ```yaml
   # For ARM/Apple Silicon:
   image: mcr.microsoft.com/azure-sql-edge:latest
   
   # Or force x86 emulation:
   platform: linux/amd64
   ```

2. **Try SQL Server 2019**:
   ```yaml
   image: mcr.microsoft.com/mssql/server:2019-latest
   ```

## 🔧 Manual Debugging Steps

### Step 1: Check container logs
```bash
docker compose logs sqlserver
docker compose logs -f sqlserver  # Follow logs in real-time
```

### Step 2: Exec into the container
```bash
docker compose exec sqlserver bash

# Inside container:
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P DevPassword123!
```

### Step 3: Test connection from host
```bash
# PowerShell
$conn = New-Object System.Data.SqlClient.SqlConnection("Server=localhost,1433;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True")
$conn.Open()
$conn.Close()
```

### Step 4: Check Docker resources
```bash
docker system df          # Check disk usage
docker stats               # Check resource usage
docker system events      # Monitor Docker events
```

## 🎯 Alternative Approaches

### Option 1: Use Azure SQL Edge (lighter weight)
```yaml
services:
  sqlserver:
    image: mcr.microsoft.com/azure-sql-edge:latest
    # ... rest of config same
```

### Option 2: Use LocalDB (Windows only)
- Install SQL Server LocalDB directly on Windows
- Skip Docker entirely for database
- Faster startup, less resource usage

### Option 3: Use PostgreSQL instead
```yaml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: devpassword
      POSTGRES_DB: devdb
    ports:
      - "5432:5432"
```

## 📊 Health Check Details

The improved health check configuration:
```yaml
healthcheck:
  test: [
   "CMD-SHELL",
   "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'DevPassword123!' -C -Q 'SELECT 1' -b -o /dev/null"
  ]
  interval: 30s      # Check every 30 seconds
  timeout: 10s       # Wait 10 seconds for response
  retries: 5         # Try 5 times before marking unhealthy
  start_period: 120s # Wait 2 minutes before starting health checks
```

## 🆘 Last Resort Solutions

### Nuclear Option 1: Complete Docker reset
```bash
docker system prune -af --volumes
# This removes EVERYTHING Docker-related
```

### Nuclear Option 2: Use external SQL Server
- Install SQL Server directly on your machine
- Update connection strings to point to localhost
- Skip Docker for database entirely

### Nuclear Option 3: Switch to different database
- Use PostgreSQL or MySQL instead
- Modify migrations and connection strings
- Generally more Docker-friendly

## 📞 Getting Help

If none of these solutions work:

1. Run `.\diagnose-sqlserver.ps1 -Verbose`
2. Share the output along with:
   - Your operating system and version
   - Docker Desktop version
   - Available system memory
   - Any specific error messages

The diagnostic script will help identify the specific issue affecting your environment.
