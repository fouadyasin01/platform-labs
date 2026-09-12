#!/usr/bin/env bash

set -euo pipefail

LOG_FILE="/var/log/platform-provision.log"

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

