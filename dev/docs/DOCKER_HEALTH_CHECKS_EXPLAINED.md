# What Makes a Docker Container "Unhealthy"?

## 🩺 Docker Health Check Mechanism

Docker containers are marked as **"unhealthy"** when their configured health check command fails repeatedly.

### Our SQL Server Health Check

In our `docker-compose.yml`, the health check is:

```yaml
healthcheck:
  test: [
    "CMD-SHELL",
    "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'DevPassword123!' -C -Q 'SELECT 1' -b -o /dev/null"
  ]
  interval: 30s      # Run check every 30 seconds
  timeout: 10s       # Wait up to 10 seconds for response
  retries: 5         # Try 5 times before marking unhealthy
  start_period: 120s # Wait 2 minutes before starting checks
```

**What this does:**
1. Runs `sqlcmd` inside the container
2. Tries to connect to SQL Server as 'sa' user
3. Executes `SELECT 1` (simple query)
4. Returns exit code 0 (success) or non-zero (failure)

## ❌ What Causes Health Check Failures

### 1. **SQL Server Not Ready** (Most Common)
```bash
# Health check fails because:
sqlcmd: Sqlcmd: Error: Microsoft ODBC Driver 17 for SQL Server : 
Login timeout expired.
# Exit code: 1 (failure)
```

**Why:** SQL Server is still starting up and not accepting connections yet.

### 2. **Authentication Issues**
```bash
# Health check fails because:
sqlcmd: Sqlcmd: Error: Microsoft ODBC Driver 17 for SQL Server : 
Login failed for user 'sa'.
# Exit code: 1 (failure)
```

**Why:** 
- SA password not set correctly
- Password doesn't meet complexity requirements
- SQL Server hasn't finished user initialization

### 3. **Memory/Resource Issues**
```bash
# Container logs show:
SQL Server shutdown due to insufficient memory.
# Health check fails because SQL Server process died
```

**Why:** 
- Not enough RAM allocated to Docker
- SQL Server consuming too much memory
- System under memory pressure

### 4. **Database Engine Not Started**
```bash
# Health check fails because:
sqlcmd: Sqlcmd: Error: Microsoft ODBC Driver 17 for SQL Server : 
A network-related or instance-specific error occurred
# Exit code: 1 (failure)
```

**Why:**
- SQL Server process crashed during startup
- Configuration error preventing startup
- Corrupt data files (rare on first run)

### 5. **Network/Port Issues**
```bash
# Health check fails because:
sqlcmd: Sqlcmd: Error: Microsoft ODBC Driver 17 for SQL Server : 
TCP Provider: No connection could be made because the target machine actively refused it
# Exit code: 1 (failure)
```

**Why:**
- SQL Server not listening on expected port
- Firewall blocking connection (rare in containers)
- Network configuration issue

## 🔄 Health Check State Transitions

```
Container Start → [starting] 
                     ↓
              [start_period: 120s]
                     ↓
          First health check runs
                     ↓
           ┌─── Success ───→ [healthy] ←──┐
           │                              │
           │                         Success
           ↓                              │
      [unhealthy] ←─── Failure ←─── [checking]
    (after 5 retries)              (running checks)
```

## 🕐 Timeline of What Happens

**0-120 seconds:** `start_period`
- Container is `[starting]`
- Health checks are NOT run yet
- SQL Server is booting up

**120+ seconds:** Health checks begin
- Every 30 seconds, Docker runs the health check
- If successful: container becomes `[healthy]` 
- If fails: try again (up to 5 retries)
- After 5 failures: container becomes `[unhealthy]`

## 🔍 Debug Commands

### Check Current Health Status
```bash
# See health status
docker ps

# Get detailed health info
docker inspect db-dev-sqlserver --format "{{json .State.Health}}" | jq

# See health check logs
docker inspect db-dev-sqlserver | jq '.[0].State.Health.Log'
```

### Manual Health Check
```bash
# Run the same command Docker runs
docker exec db-dev-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P DevPassword123! -C -Q "SELECT 1"

# Check exit code
echo $? # Should be 0 for success
```

### Monitor Health Checks in Real-Time
```bash
# Watch health status change
watch -n 5 'docker inspect db-dev-sqlserver --format "{{.State.Health.Status}}"'

# Follow container logs during startup
docker logs -f db-dev-sqlserver
```

## 🛠️ Common Fixes by Root Cause

### If SQL Server Not Ready:
```bash
# Solution: Wait longer or increase start_period
# Edit docker-compose.yml:
start_period: 180s  # 3 minutes instead of 2
```

### If Authentication Issues:
```bash
# Solution: Check password and try reset
docker compose stop sqlserver
docker volume rm dev_sqlserver_data
docker compose up -d sqlserver
```

### If Memory Issues:
```bash
# Solution: Increase Docker Desktop memory
# Docker Desktop → Settings → Resources → Memory: 4GB+

# Or limit SQL Server memory in docker-compose.yml:
environment:
  - MSSQL_MEMORY_LIMIT_MB=2048
```

### If Port/Network Issues:
```bash
# Solution: Check what's using port 1433
netstat -ano | findstr :1433  # Windows
lsof -i :1433                 # Linux/Mac

# Or use different port:
ports:
  - "14330:1433"
```

## 💡 Key Insights

1. **"Unhealthy" ≠ "Broken"** - Often just means "not ready yet"
2. **Timing is critical** - SQL Server needs 2-3 minutes to start
3. **Health checks are strict** - One failed query = failed check
4. **Resource constraints** are common cause
5. **Fresh containers** take longer than existing ones

## 🎯 Prevention

1. **Generous timing**: Use long `start_period` and reasonable `interval`
2. **Resource allocation**: Ensure adequate RAM/CPU for Docker
3. **Simple health checks**: Use basic queries, not complex operations
4. **Monitoring**: Watch logs during first startup
5. **Gradual rollout**: Test locally before production

The key is understanding that "unhealthy" is Docker's way of saying "the service inside this container isn't responding to my health check the way I expect." It's often a timing or resource issue, not a fundamental problem with the application.
