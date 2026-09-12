#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/common.sh"

APP_USER="multiapp"
APP_DIR="/opt/multiapp"
VENV_DIR="${APP_DIR}/venv"

setup_backend() {
    info "Setting up backend application"

    mkdir -p "${APP_DIR}"

    cp "${PROJECT_DIR}/app/app.py" "${APP_DIR}/app.py"

    python3 -m venv "${VENV_DIR}"

    "${VENV_DIR}/bin/pip" install --upgrade pip
    "${VENV_DIR}/bin/pip" install flask

    chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"

    info "Backend application setup completed"
}

setup_backend