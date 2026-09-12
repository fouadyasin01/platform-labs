#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common.sh"

DNS_HOST="${DNS_HOST:-localhost}"

verify_dns() {
    info "Verifying DNS resolution for ${DNS_HOST}"

    if getent hosts "${DNS_HOST}" >/dev/null 2>&1; then
        info "DNS resolution successful: ${DNS_HOST}"
    else
        error "DNS resolution failed: ${DNS_HOST}"
        exit 1
    fi
}

verify_dns