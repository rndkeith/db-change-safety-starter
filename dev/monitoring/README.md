# Development Monitoring Stack

This directory contains configuration files for optional monitoring services in the development environment.

## Services

### Prometheus (Metrics Collection)
- **URL:** http://localhost:9090
- **Purpose:** Collects and stores time-series metrics
- **Config:** `prometheus-config.yml`

### Grafana (Metrics Visualization)
- **URL:** http://localhost:3000
- **Username:** admin
- **Password:** admin123
- **Purpose:** Dashboards and visualization of metrics

## Starting Monitoring Services

```bash
# Start basic development environment
docker compose up -d

# Start with monitoring services
docker compose --profile monitoring up -d

# View all services
docker compose ps
```

## Available Dashboards

1. **Database Development Monitoring** - Basic system information and status

## Extending Monitoring

### Adding SQL Server Metrics

To monitor SQL Server performance, you can add a SQL Server exporter:

```yaml
# Add to docker-compose.yml
sqlserver-exporter:
  image: awaragi/prometheus-mssql-exporter
  environment:
    - SERVER=sqlserver
    - USERNAME=sa
    - PASSWORD=DevPassword123!
    - DEBUG=app
  ports:
    - "4000:4000"
  depends_on:
    - sqlserver
  profiles:
    - monitoring
```

Then uncomment the SQL Server job in `prometheus-config.yml`.

### Adding Application Metrics

If your application exposes metrics (e.g., at `/metrics` endpoint):

1. Uncomment the application job in `prometheus-config.yml`
2. Update the target to point to your application
3. Create custom Grafana dashboards for your business metrics

### Custom Dashboards

1. Create new dashboard JSON files in `grafana/dashboards/`
2. Restart Grafana service: `docker compose restart grafana`
3. Dashboards will be automatically loaded

### Alerting

To set up alerting:

1. Configure alerting rules in Prometheus
2. Set up Alertmanager for notifications
3. Create notification channels in Grafana

## Troubleshooting

### Prometheus not starting
- Check that `prometheus-config.yml` is valid YAML
- Verify volume mounts are correct
- Check container logs: `docker compose logs prometheus`

### Grafana not showing data
- Verify Prometheus datasource is configured correctly
- Check that Prometheus is reachable from Grafana container
- Verify dashboard JSON is valid

### Performance Issues
- Monitoring services can consume resources
- Use profiles to run only needed services
- Adjust scrape intervals in prometheus-config.yml

## Production Considerations

**Note:** This monitoring setup is for development only. For production:

- Use persistent storage for Prometheus data
- Implement proper authentication and security
- Set up proper alerting and notification channels
- Consider using managed monitoring services
- Implement proper backup and retention policies
