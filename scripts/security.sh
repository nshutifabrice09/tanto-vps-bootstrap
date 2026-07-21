#!/usr/bin/env bash

set -Eeuo pipefail

VERSION="1.0.0"

LOG_FILE="/var/log/gc-vps-bootstrap-security.log"

initialize_logging() {

   mkdir -p "$(dirname "$LOG_FILE")"

}

log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

error() {

    local message="[$(date '+%F %T')] ERROR: $*"

    if [[ -w "$(dirname "$LOG_FILE")" || $EUID -eq 0 ]]; then
        echo "$message" | tee -a "$LOG_FILE" >&2
    else
        echo "$message" >&2
    fi

}

show_help() {

cat <<EOF

Security Hardening Module

Usage:

sudo ./security.sh [OPTION]

Options:

  --help, -h        Show this help message
  --version, -v     Show module version

Description:

  Applies production security hardening by:

    • Installing UFW
    • Installing Fail2Ban
    • Installing Auditd
    • Enabling unattended security upgrades
    • Hardening SSH configuration
    • Configuring the firewall

Example:

  sudo ./security.sh

EOF

}

show_version() {

    echo "Security Hardening Module v${VERSION}"

}

backup_file() {
    local file="$1"

    if [[ -f "$file" ]]; then
        cp "$file" "${file}.bak.$(date +%F-%H%M%S)"
        log "Backup created for $file"
    fi
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        error "This script must be run as root."
        exit 1
    fi
}

initialize_logging() {

    mkdir -p "$(dirname "$LOG_FILE")"

}

detect_ssh_service() {
    if systemctl list-unit-files | grep -q "^ssh.service"; then
        echo "ssh"
    elif systemctl list-unit-files | grep -q "^sshd.service"; then
        echo "sshd"
    else
        error "Unable to determine SSH service name."
        exit 1
    fi
}

configure_unattended_upgrades() {
    log "Installing automatic security update packages..."

    apt install -y \
        unattended-upgrades \
        apt-listchanges

    dpkg-reconfigure -f noninteractive unattended-upgrades

    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades

    log "Automatic security updates enabled."
}

configure_ufw() {
    log "Configuring UFW firewall..."

    ufw default deny incoming
    ufw default allow outgoing

    ufw allow OpenSSH
    ufw allow 80/tcp
    ufw allow 443/tcp

    ufw --force enable

    log "UFW firewall configured."
}

configure_fail2ban() {
    log "Configuring Fail2Ban..."

    cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban

    log "Fail2Ban configured."
}

configure_auditd() {
    log "Enabling auditd..."

    systemctl enable auditd
    systemctl restart auditd

    log "Auditd enabled."
}

harden_ssh() {
    local ssh_service
    ssh_service=$(detect_ssh_service)

    log "Hardening SSH..."

    backup_file /etc/ssh/sshd_config

    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
        /etc/ssh/sshd_config

    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
        /etc/ssh/sshd_config

    sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' \
        /etc/ssh/sshd_config

    if ! grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
        echo "PermitRootLogin no" >> /etc/ssh/sshd_config
    fi

    if ! grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
        echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    fi

    if ! grep -q "^X11Forwarding" /etc/ssh/sshd_config; then
        echo "X11Forwarding no" >> /etc/ssh/sshd_config
    fi

    sshd -t

    systemctl restart "$ssh_service"

    log "SSH hardening completed."
}

security_summary() {
    log "Security configuration complete."

    echo
    echo "========================================"
    echo " Security Hardening Complete"
    echo "========================================"
    echo

    ufw status verbose || true

    echo
    fail2ban-client status sshd || true

    echo
    echo "Log file:"
    echo "$LOG_FILE"
}

main() {

    case "${1:-}" in

        --help|-h)

            show_help
            exit 0
            ;;

        --version|-v)

            show_version
            exit 0
            ;;

        "")

            ;;

        *)

            echo "Unknown option: $1"
            echo
            show_help
            exit 1
            ;;

    esac

    require_root

    initialize_logging

    log "Starting security hardening..."

    apt update

    apt install -y \
        ufw \
        fail2ban \
        auditd

    configure_unattended_upgrades
    harden_ssh
    configure_ufw
    configure_fail2ban
    configure_auditd

    security_summary
}
main "$@"
