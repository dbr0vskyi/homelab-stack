# Monitoring Stack - Quick Guide

Prometheus + Grafana + thermal monitoring for performance tracking and thermal management.

## Deployment

Deploy the complete monitoring stack:

```bash
# Method 1: Via setup script
./scripts/setup.sh monitoring

# Method 2: Via deploy script
./scripts/deploy-monitoring.sh

# Method 3: Enable in .env then full setup
echo "ENABLE_MONITORING=true" >> .env
./scripts/setup.sh
```

## Access Points

- **Prometheus**: http://localhost:9090 (metrics collection)
- **Grafana**: http://localhost:3000 (dashboards, admin/admin)
- **Thermal Exporter**: http://localhost:9200/metrics (Pi sensors)
- **Node Exporter**: http://localhost:9100/metrics (system stats)

## Management

```bash
# Start monitoring
./scripts/manage.sh monitoring-start

# Stop monitoring
./scripts/manage.sh monitoring-stop

# Check status
./scripts/manage.sh monitoring-status

# Test thermal sensors
./scripts/manage.sh thermal-test
```

## Key Metrics

- `rpi_cpu_temperature_celsius` - CPU temperature
- `rpi_throttling_active` - Throttling status
- `rpi_cpu_frequency_hz` - Current CPU frequency
- `rpi_voltage_volts` - Supply voltage

## Alerts

- **Warning**: >75°C (2min)
- **Critical**: >80°C (1min)
- **Throttling**: Any throttling detected
- **Under-voltage**: Power supply issues

## N8N Integration

Add webhook endpoint in N8N workflows:

- URL: `http://n8n:5678/webhook/thermal-alert`
- Method: POST
- Payload: `{"alert_type": "warning", "temperature": 78, "message": "High temp"}`

## Troubleshooting

1. **Services not starting**: Check `docker logs homelab-prometheus`
2. **No thermal data**: Verify Pi platform detection
3. **High memory usage**: Monitoring uses ~768MB RAM on Pi
4. **Disk space**: 7-day retention configured for Pi constraints
