## 💰 Flyway License (Optional)

The development environment uses **Flyway Community (free)** by default. To enable Flyway Teams+ features:

```bash
# Set license key for current session
export FLYWAY_LICENSE_KEY="your-license-key"

# Or add to flyway/flyway.conf
flyway.licenseKey=your-license-key

# Teams+ features:
# - Dry run SQL preview: flyway migrate -dryRunOutput
# - Undo migrations: flyway undo  
# - Advanced validation
```

See `FLYWAY_EDITIONS.md` for license options and pricing.

---

## 🚨 SQL Server Troubleshooting

**If SQL Server container is unhealthy or won't start:**

```bash
# Quick fix (tries common solutions)
.\quick-fix-sqlserver.ps1

# Detailed diagnosis  
.\diagnose-sqlserver.ps1

# SSL Certificate fix (most common issue):
docker compose stop sqlserver
docker compose up -d sqlserver
# Wait 2-3 minutes - health check now includes -C parameter

# Manual reset (removes data!)
docker compose stop sqlserver
docker volume rm dev_sqlserver_data
docker compose up -d sqlserver
```

**Common issues:**
- **SSL Certificate Error**: Fixed with `-C` parameter in health check
- Container needs 2-3 minutes to fully start
- Requires 4GB+ RAM in Docker Desktop
- Port 1433 might be in use by another service

See `SSL_CERTIFICATE_FIX.md` and `SQL_SERVER_TROUBLESHOOTING.md` for complete guides.

---

# Development Environment Helper

## 🚀 Starting Services

```bash
# Basic SQL Server only
docker compose up -d

# With specific services
docker compose --profile migration up -d          # Include Flyway
docker compose --profile cache up -d              # Include Redis  
docker compose --profile monitoring up -d         # Include Prometheus + Grafana
docker compose --profile gui up -d                # Include Azure Data Studio

# Multiple profiles
docker compose --profile monitoring --profile cache up -d

# All services
docker compose --profile migration --profile cache --profile monitoring --profile gui up -d
```

## 🛑 Stopping Services Properly

**The Problem:** `docker compose down` only stops containers started in the current profile context.

### Quick Solutions:

```bash
# Windows
.\cleanup.ps1                    # Stop everything, keep data
.\cleanup.ps1 -RemoveVolumes     # Stop everything, remove data

# Linux/Mac  
chmod +x cleanup.sh                  # Make executable first
./cleanup.sh                    # Stop everything, keep data
./cleanup.sh -v                 # Stop everything, remove data
```

### Manual Method:

```bash
# Stop each profile you might have started
docker compose down                              # Base services
docker compose --profile migration down
docker compose --profile cache down  
docker compose --profile monitoring down
docker compose --profile gui down

# Remove volumes (optional - removes all data!)
docker compose down -v
```

### Nuclear Option:
```bash
# Stop ALL Docker containers (not just this project)
docker stop $(docker ps -q)
docker system prune -af --volumes  # ⚠️ Removes EVERYTHING
```

## 📊 Monitoring Services

When using `--profile monitoring`:

- **Prometheus:** http://localhost:9090  
- **Grafana:** http://localhost:3000 (admin/admin123)

## 🗄️ Database Access

- **Host:** localhost:1433
- **Database:** DevDB  
- **Username:** sa
- **Password:** DevPassword123!

## 🔧 Useful Commands

```bash
# View running containers
docker compose ps

# View logs  
docker compose logs sqlserver
docker compose logs -f prometheus    # Follow logs

# Execute commands in containers
docker compose exec sqlserver bash
docker compose exec sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P DevPassword123!

# Check resource usage
docker stats

# View Docker volumes
docker volume ls --filter "name=dev_"
```

## 🐛 Troubleshooting

### Container Won't Start
```bash
# Check logs
docker compose logs [service-name]

# Restart specific service  
docker compose restart sqlserver

# Rebuild if needed
docker compose up --build -d
```

### Port Already in Use
```bash
# Find what's using the port
netstat -ano | findstr :1433     # Windows
lsof -i :1433                    # Linux/Mac

# Kill the process or change ports in docker-compose.yml
```

### Volume Issues
```bash
# Reset everything (⚠️ removes data)
.\cleanup.ps1 -RemoveVolumes -Force

# Or manually
docker compose down -v
docker volume prune -f
```

### SQL Server Container Issues
```bash
# Check health
docker compose exec sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P DevPassword123! -Q "SELECT 1"

# Reset SQL Server data
docker compose stop sqlserver
docker volume rm dev_sqlserver_data
docker compose up -d sqlserver
```

## 🔄 Complete Environment Reset

```bash
# Windows
.\cleanup.ps1 -RemoveVolumes
.\init-db.ps1 -Reset

# Linux/Mac
./cleanup.sh -v
# Then restart services manually
```

This ensures a completely clean development environment.
