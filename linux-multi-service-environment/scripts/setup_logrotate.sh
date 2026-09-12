#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/common.sh"

LOG_DIR="/var/log/multiapp"
LOGROTATE_CONFIG="/etc/logrotate.d/multiapp"

setup_logrotate() {
    info "Configuring application log rotation"

    mkdir -p "${LOG_DIR}"

    touch "${LOG_DIR}/app.log"

    chown -R multiapp:multiapp "${LOG_DIR}"

    cp "${PROJECT_DIR}/logrotate/multiapp" "${LOGROTATE_CONFIG}"

    chmod 644 "${LOGROTATE_CONFIG}"

    logrotate -d "${LOGROTATE_CONFIG}" >/dev/null

    info "Application log rotation configured successfully"
}

setup_logrotate