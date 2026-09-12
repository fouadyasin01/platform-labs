#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/common.sh"

MONITORING_SCRIPT="/usr/local/bin/multiapp-health-check"
CRON_FILE="/etc/cron.d/multiapp-health"

setup_monitoring() {
    info "Configuring application health monitoring"

    cp "${PROJECT_DIR}/monitoring/health_check.sh" "${MONITORING_SCRIPT}"

    chmod 755 "${MONITORING_SCRIPT}"

    cat > "${CRON_FILE}" <<EOF
*/5 * * * * root ${MONITORING_SCRIPT}
EOF

    chmod 644 "${CRON_FILE}"

    info "Application health monitoring configured successfully"
}

setup_monitoring