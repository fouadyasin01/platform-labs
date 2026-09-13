#!/usr/bin/env bash

set -euo pipefail

APP_DIR="/opt/multiapp"
BACKUP_DIR="/var/backups/multiapp"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP_FILE="${BACKUP_DIR}/multiapp-${TIMESTAMP}.tar.gz"


info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*"
}

backup_app() {
    info "Starting application backup"

    mkdir -p "${BACKUP_DIR}"

    tar -czf "${BACKUP_FILE}" \
        -C "$(dirname "${APP_DIR}")" \
        "$(basename "${APP_DIR}")"

    chown root:root "${BACKUP_FILE}"
    chmod 600 "${BACKUP_FILE}"

    info "Application backup created: ${BACKUP_FILE}"
}

backup_app
