#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/scripts/common.sh"

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "ERROR: This script must be run as root." >&2
        exit 1
    fi
}

validate_environment() {
    info "Validating environment"

    require_command "bash"
    require_command "systemctl"
    require_command "ip"
    require_command "ss"

    info "Environment validation completed"
}

validate_os() {
    info "Validating operating system"

    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine operating system: /etc/os-release is missing"
        exit 1
    fi

    source /etc/os-release

    if [[ "${ID}" != "ubuntu" && "${ID}" != "debian" ]]; then
        error "Unsupported operating system: ${ID}"
        error "This provisioning script supports Ubuntu and Debian"
        exit 1
    fi

    require_command "apt-get"

    info "Operating system: ${PRETTY_NAME}"
    info "Package manager: apt"
}

install_dependencies() {
    info "Starting dependency installation"

    "${SCRIPT_DIR}/scripts/install_dependencies.sh"

    info "Dependency installation completed"
}

setup_app_user() {
    info "Starting application user setup"

    "${SCRIPT_DIR}/scripts/setup_app_user.sh"

    info "Application user setup completed"
}

setup_backend() {
    info "Starting backend setup"

    "${SCRIPT_DIR}/scripts/setup_backend.sh"

    info "Backend setup completed"
}


setup_systemd() {
    info "Starting systemd service setup"

    "${SCRIPT_DIR}/scripts/setup_systemd.sh"

    info "systemd service setup completed"
}

setup_tls() {
    info "Starting TLS setup"

    "${SCRIPT_DIR}/scripts/setup_tls.sh"

    info "TLS setup completed"
}

setup_nginx() {
    info "Starting Nginx setup"

    "${SCRIPT_DIR}/scripts/setup_nginx.sh"

    info "Nginx setup completed"
}


main() {
    require_root

    touch "$LOG_FILE"

    info "Starting Linux multi-service environment provisioning"

    validate_environment
    validate_os
    install_dependencies
    setup_app_user
    setup_backend
    setup_systemd
    setup_tls
    setup_nginx

    info "Provisioning framework initialized"
    info "Provisioning completed successfully"
}

main "$@"