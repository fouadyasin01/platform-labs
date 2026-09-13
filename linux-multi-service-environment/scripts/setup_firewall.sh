#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common.sh"

setup_firewall() {
    info "Configuring UFW firewall"

    ufw default deny incoming
    ufw default allow outgoing

    ufw allow 22/tcp comment "SSH"
    ufw allow 80/tcp comment "HTTP"
    ufw allow 443/tcp comment "HTTPS"

    ufw --force enable

    info "UFW firewall configured successfully"
}

setup_firewall