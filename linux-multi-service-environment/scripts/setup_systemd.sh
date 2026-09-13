#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/common.sh"

SERVICE_NAME="multiapp.service"
SYSTEMD_PATH="/etc/systemd/system/${SERVICE_NAME}"

setup_systemd() {
    info "Configuring systemd service"

    cp "${PROJECT_DIR}/systemd/${SERVICE_NAME}" "${SYSTEMD_PATH}"

    chmod 644 "${SYSTEMD_PATH}"

    systemctl daemon-reload

    systemctl enable "${SERVICE_NAME}"
    systemctl restart "${SERVICE_NAME}"

    info "systemd service configured successfully"
}

setup_systemd