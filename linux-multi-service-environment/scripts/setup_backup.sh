#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common.sh"

BACKUP_SCRIPT="/usr/local/bin/multiapp-backup"
CRON_FILE="/etc/cron.d/multiapp-backup"

setup_backup() {
    info "Configuring automated application backups"

    cp "${SCRIPT_DIR}/backup_app.sh" "${BACKUP_SCRIPT}"

    chmod 755 "${BACKUP_SCRIPT}"

    cat > "${CRON_FILE}" <<EOF2
0 2 * * * root ${BACKUP_SCRIPT}
EOF2

    chmod 644 "${CRON_FILE}"

    info "Automated application backups configured successfully"
}

setup_backup
