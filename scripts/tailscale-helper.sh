#!/bin/bash

# Tailscale Domain Discovery Helper - Refactored Version
# Helps you find your exact Tailscale domain and integrates with the homelab setup

set -e

# Get script directory and source library modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source required library modules
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/tailscale.sh"

# Run interactive Tailscale setup helper
interactive_tailscale_setup