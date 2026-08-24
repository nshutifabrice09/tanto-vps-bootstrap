#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/../lib/common.sh"

VERSION="1.0.0"

CONFIG_FILE="$(dirname "$0")/../config/defaults.conf"

LOG_FILE="${SECURITY_LOG_FILE}"

load_config "$CONFIG_FILE"

##########
# Logging
##########

initialize_logging() {

    mkdir -p "$(dirname "$LOG_FILE")"

}

log() {

    printf '[%s] %s\n' \
        "$(date '+%F %T')" \
        "$*" | tee -a "$LOG_FILE"

}


#######
# Help
#######

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


##########
# Version
##########

show_version() {

    echo "Security Hardening Module v${VERSION}"

}


##############
# Backup File
##############

backup_file() {

    local file="$1"

    if [[ ! -f "$file" ]]; then

        warn "File not found. Backup skipped: ${file}"

        return

    fi

    local backup

    backup="${file}.bak.$(date '+%Y%m%d-%H%M%S')"

    cp "$file" "$backup"

    log "Backup created: ${backup}"

}


#####################
# Detect SSH Service
#####################

detect_ssh_service() {

    require_command systemctl

    if systemctl list-unit-files | grep -q '^ssh.service'; then

        echo "ssh"

    elif systemctl list-unit-files | grep -q '^sshd.service'; then

        echo "sshd"

    else

        error "Unable to determine SSH service name."

        exit 1

    fi

}


################################
# Configure Unattended Upgrades
################################

configure_unattended_upgrades() {

    log "Installing automatic security update packages..."

    require_command apt-get
    require_command dpkg
    require_command systemctl

    run_command apt-get install -y \
        unattended-upgrades \
        apt-listchanges

    run_command dpkg-reconfigure \
        -f noninteractive \
        unattended-upgrades

    run_command systemctl enable unattended-upgrades
    run_command systemctl restart unattended-upgrades

    log "Automatic security updates enabled."

}


################
# Configure UFW
################

configure_ufw() {

    log "Configuring UFW firewall..."

    require_command ufw

    run_command ufw default deny incoming
    run_command ufw default allow outgoing

    run_command ufw allow OpenSSH
    run_command ufw allow 80/tcp
    run_command ufw allow 443/tcp

    run_command ufw --force enable

    log "UFW firewall configured."

}


#####################
# Configure Fail2Ban
#####################

configure_fail2ban() {

    log "Configuring Fail2Ban..."

    require_command systemctl

    cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
EOF

    run_command systemctl enable fail2ban
    run_command systemctl restart fail2ban

    log "Fail2Ban configured."

}


###################
# Configure Auditd
###################

configure_auditd() {

    log "Enabling auditd..."

    require_command systemctl

    run_command systemctl enable auditd
    run_command systemctl restart auditd

    log "Auditd enabled."

}


#############
# Harden SSH
#############

harden_ssh() {

    local ssh_service
    local ssh_config="/etc/ssh/sshd_config"

    ssh_service="$(detect_ssh_service)"

    log "Hardening SSH..."

    require_command sed
    require_command grep
    require_command sshd
    require_command systemctl

    if [[ ! -f "$ssh_config" ]]; then

        error "SSH configuration file not found: ${ssh_config}"

        exit 1

    fi

    backup_file "$ssh_config"

    sed -i \
        's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
        "$ssh_config"

    sed -i \
        's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
        "$ssh_config"

    sed -i \
        's/^#\?X11Forwarding.*/X11Forwarding no/' \
        "$ssh_config"


    if ! grep -q '^PermitRootLogin' "$ssh_config"; then

        echo "PermitRootLogin no" >> "$ssh_config"

    fi


    if ! grep -q '^PasswordAuthentication' "$ssh_config"; then

        echo "PasswordAuthentication no" >> "$ssh_config"

    fi


    if ! grep -q '^X11Forwarding' "$ssh_config"; then

        echo "X11Forwarding no" >> "$ssh_config"

    fi


    log "Validating SSH configuration..."

    run_command sshd -t

    log "SSH configuration is valid."

    run_command systemctl restart "$ssh_service"

    log "SSH hardening completed."

}


###################
# Security Summary
###################

security_summary() {

    log "Security configuration complete."

    echo
    echo "========================================"
    echo " Security Hardening Complete"
    echo "========================================"
    echo

    if command -v ufw >/dev/null 2>&1; then

        ufw status verbose || true

    fi

    echo

    if command -v fail2ban-client >/dev/null 2>&1; then

        fail2ban-client status sshd || true

    fi

    echo
    echo "Log file:"
    echo "$LOG_FILE"

}


#######
# Main
#######

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

            error "Unknown option: $1"

            echo

            show_help

            exit 1
            ;;

    esac

    require_root

    initialize_logging

    log "Starting security hardening..."

    require_command apt-get

    run_command apt-get update

    run_command apt-get install -y \
        ufw \
        fail2ban \
        auditd

    configure_unattended_upgrades

    configure_ufw

    configure_fail2ban

    configure_auditd

    harden_ssh

    security_summary

    success "Security hardening completed successfully."

}


main "$@"