#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common.sh"

install_dependencies() {
    info "Updating package index"

    apt-get update

    info "Installing required packages"

    apt-get install -y \
        nginx \
        python3 \
        python3-venv \
        python3-pip \
        curl \
        ufw \
        fail2ban \
        openssl \
        logrotate

    info "Required packages installed successfully"
}

install_dependencies