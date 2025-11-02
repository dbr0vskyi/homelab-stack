FROM python:3.11-alpine

# Install system dependencies for Raspberry Pi
RUN apk add --no-cache \
    gcc \
    musl-dev \
    linux-headers \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy requirements first for better caching
COPY config/thermal-exporter/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY config/thermal-exporter/thermal_exporter.py .
COPY config/thermal-exporter/entrypoint.sh .

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Create non-root user
RUN addgroup -g 1000 thermal && \
    adduser -D -s /bin/sh -u 1000 -G thermal thermal

# Set ownership
RUN chown -R thermal:thermal /app

# Switch to non-root user
USER thermal

# Expose metrics port
EXPOSE 9200

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:9200/metrics || exit 1

# Run the exporter
ENTRYPOINT ["./entrypoint.sh"]