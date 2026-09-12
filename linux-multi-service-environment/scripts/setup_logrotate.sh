#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/common.sh"


LOGROTATE_CONFIG="/etc/logrotate.d/multiapp"

setup_logrotate() {
    info "Configuring application log rotation"

    mkdir -p "${APP_LOG_DIR}"

    touch "${APP_LOG_DIR}/app.log"

    chown -R "${APP_USER}:${APP_GROUP}" "${APP_LOG_DIR}"

    cp "${PROJECT_DIR}/logrotate/multiapp" "${LOGROTATE_CONFIG}"

    chmod 644 "${LOGROTATE_CONFIG}"

    logrotate -d "${LOGROTATE_CONFIG}" >/dev/null

    info "Application log rotation configured successfully"
}

setup_logrotate