#!/bin/bash
# Monitoring Stack Deployment Script - Refactored
# Deploy Prometheus + Grafana + Thermal Monitoring

# Initialize script with common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/monitoring.sh"

# Initialize script
init_script

# Main deployment - simply call the library function
main() {
    deploy_monitoring_stack
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi