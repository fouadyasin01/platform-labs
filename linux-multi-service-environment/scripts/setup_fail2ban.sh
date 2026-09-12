#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/common.sh"

FAIL2BAN_CONFIG="/etc/fail2ban/jail.local"

setup_fail2ban() {
    info "Configuring fail2ban"

    cp "${PROJECT_DIR}/fail2ban/jail.local" "${FAIL2BAN_CONFIG}"

    chmod 644 "${FAIL2BAN_CONFIG}"

    systemctl enable fail2ban
    systemctl restart fail2ban

    info "fail2ban configured successfully"
}

setup_fail2ban
