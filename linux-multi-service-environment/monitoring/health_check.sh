#!/usr/bin/env bash

set -euo pipefail

APP_LOG_DIR="/var/log/multiapp"

HEALTH_URL="https://127.0.0.1/health"
HEALTH_LOG="${APP_LOG_DIR}/health-check.log"

check_health() {
    local timestamp

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    if curl -k --fail --silent --show-error "${HEALTH_URL}" >/dev/null; then
        echo "${timestamp} [INFO] Backend health check passed" >> "${HEALTH_LOG}"
    else
        echo "${timestamp} [ERROR] Backend health check failed" >> "${HEALTH_LOG}"
        return 1
    fi
}

check_health