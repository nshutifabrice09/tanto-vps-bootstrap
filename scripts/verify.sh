#!/usr/bin/env bash

set -Eeuo pipefail

################################################################################
# Logging
################################################################################

info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

################################################################################
# Helpers
################################################################################

check_service() {

    local service="$1"

    if systemctl is-active --quiet "$service"; then
        printf "  %-20s : ✅ Running\n" "$service"
    else
        printf "  %-20s : ❌ Not running\n" "$service"
    fi
}

################################################################################
# System Information
################################################################################

system_information() {

    echo
    echo "=============================="
    echo "SYSTEM"
    echo "=============================="

    hostnamectl

    echo
    uptime

    echo
    free -h

    echo
    df -h /

    echo
    swapon --show || true
}

################################################################################
# Services
################################################################################

verify_services() {

    echo
    echo "=============================="
    echo "SERVICES"
    echo "=============================="

    check_service ssh

    if command -v docker >/dev/null; then
        check_service docker
    fi

    if systemctl list-unit-files | grep -q nginx.service; then
        check_service nginx
    fi

    if command -v tailscale >/dev/null; then
        check_service tailscaled
    fi
}

################################################################################
# Firewall
################################################################################

verify_firewall() {

    echo
    echo "=============================="
    echo "FIREWALL"
    echo "=============================="

    if command -v ufw >/dev/null; then
        ufw status
    else
        warn "UFW not installed."
    fi
}

################################################################################
# Docker
################################################################################

verify_docker() {

    if ! command -v docker >/dev/null; then
        return
    fi

    echo
    echo "=============================="
    echo "DOCKER"
    echo "=============================="

    docker ps

    echo
    docker system df
}

################################################################################
# Network
################################################################################

verify_network() {

    echo
    echo "=============================="
    echo "LISTENING PORTS"
    echo "=============================="

    ss -tulpn
}

################################################################################
# Failed Services
################################################################################

verify_failed_services() {

    echo
    echo "=============================="
    echo "FAILED SYSTEMD UNITS"
    echo "=============================="

    systemctl --failed --no-pager
}

################################################################################
# Recent Errors
################################################################################

verify_logs() {

    echo
    echo "=============================="
    echo "RECENT SYSTEM ERRORS"
    echo "=============================="

    journalctl -p err -n 20 --no-pager
}

#######
# Main
#######

main() {

    info "Running VPS verification..."

    system_information

    verify_services

    verify_firewall

    verify_docker

    verify_network

    verify_failed_services

    verify_logs

    info "Verification completed."
}

main "$@"
