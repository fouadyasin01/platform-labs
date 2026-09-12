#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common.sh"


create_app_user() {
    info "Creating application user"

    if id "${APP_USER}" >/dev/null 2>&1; then
        info "Application user already exists: ${APP_USER}"
    else
        useradd \
            --system \
            --user-group \
            --create-home \
            --shell /usr/sbin/nologin \
            "${APP_USER}"

        info "Created application user: ${APP_USER}"
    fi
}

create_app_user