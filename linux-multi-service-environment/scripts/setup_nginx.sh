#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/common.sh"

NGINX_CONFIG="/etc/nginx/sites-available/multiapp.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/multiapp.conf"

setup_nginx() {
    info "Configuring Nginx reverse proxy"

    cp "${PROJECT_DIR}/nginx/multiapp.conf" "${NGINX_CONFIG}"

    ln -sfn "${NGINX_CONFIG}" "${NGINX_ENABLED}"

    rm -f /etc/nginx/sites-enabled/default

    nginx -t

    systemctl enable nginx
    systemctl restart nginx

    info "Nginx reverse proxy configured successfully"
}

setup_nginx