#!/usr/bin/env bash

set -euo pipefail

LOG_FILE="/var/log/platform-provision.log"

APP_USER="multiapp"
APP_GROUP="multiapp"
APP_DIR="/opt/multiapp"
APP_LOG_DIR="/var/log/multiapp"
APP_PORT="3000"


log() {
    local level="$1"
    shift

    local message="$*"
    local timestamp

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    echo "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

info() {
    log "INFO" "$@"
}

warn() {
    log "WARN" "$@"
}

error() {
    log "ERROR" "$@"
}


require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        error "Required command not found: $command_name"
        exit 1
    fi
}