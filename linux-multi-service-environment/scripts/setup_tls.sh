#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common.sh"

CERT_DIR="/etc/nginx/ssl"
CERT_FILE="${CERT_DIR}/multiapp.crt"
KEY_FILE="${CERT_DIR}/multiapp.key"

setup_tls() {
    info "Configuring self-signed TLS certificate"

    mkdir -p "${CERT_DIR}"

    if [[ ! -f "${CERT_FILE}" || ! -f "${KEY_FILE}" ]]; then
        openssl req \
            -x509 \
            -nodes \
            -days 365 \
            -newkey rsa:2048 \
            -keyout "${KEY_FILE}" \
            -out "${CERT_FILE}" \
            -subj "/CN=localhost"

        chmod 600 "${KEY_FILE}"
        chmod 644 "${CERT_FILE}"

        info "Self-signed TLS certificate generated"
    else
        info "TLS certificate already exists"
    fi
}

setup_tls