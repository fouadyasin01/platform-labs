#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common.sh"

DNS_HOST="${DNS_HOST:-localhost}"

verify_dns() {
    info "Verifying DNS resolution for ${DNS_HOST}"

    local resolved_ip

    if ! resolved_ip=$(getent hosts "${DNS_HOST}" | awk '{print $1}' | head -n1); then
        error "DNS resolution failed: ${DNS_HOST}"
        exit 1
    fi

    info "DNS resolution successful: ${DNS_HOST} -> ${resolved_ip}"
}

verify_dns