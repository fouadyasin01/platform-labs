#!/usr/bin/env bash

set -euo pipefail

HEALTH_URL="https://127.0.0.1/health"
LOG_FILE="/var/log/multiapp/health-check.log"

check_health() {
    local timestamp

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    if curl -k --fail --silent --show-error "${HEALTH_URL}" >/dev/null; then
        echo "${timestamp} [INFO] Backend health check passed" >> "${LOG_FILE}"
    else
        echo "${timestamp} [ERROR] Backend health check failed" >> "${LOG_FILE}"
        return 1
    fi
}

check_health