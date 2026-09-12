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

main() {
    require_root

    touch "$LOG_FILE"

    info "Starting Linux multi-service environment provisioning"
    info "Provisioning framework initialized"
    info "Provisioning completed successfully"
}

main "$@"