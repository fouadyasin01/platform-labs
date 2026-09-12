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

main() {
    require_root

    touch "$LOG_FILE"

    info "Starting Linux multi-service environment provisioning"

    validate_environment
    validate_os

    info "Provisioning framework initialized"
    info "Provisioning completed successfully"
}

main "$@"