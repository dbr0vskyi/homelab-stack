#!/bin/sh

# Entrypoint script for thermal exporter
# Handles platform detection and graceful startup

echo "Starting Raspberry Pi Thermal Exporter..."

# Check if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ]; then
    echo "WARNING: Not running on Raspberry Pi - some metrics may be unavailable"
fi

# Check if vcgencmd is available
if ! command -v vcgencmd >/dev/null 2>&1; then
    echo "WARNING: vcgencmd not available - using fallback thermal sensors"
fi

# Set default environment variables if not provided
export METRICS_PORT="${METRICS_PORT:-9200}"
export COLLECT_INTERVAL="${COLLECT_INTERVAL:-30}"

echo "Configuration:"
echo "  Metrics Port: $METRICS_PORT"
echo "  Collection Interval: ${COLLECT_INTERVAL}s"
echo "  N8N Webhook: ${N8N_WEBHOOK_URL:-disabled}"

# Start the thermal exporter
exec python3 thermal_exporter.py