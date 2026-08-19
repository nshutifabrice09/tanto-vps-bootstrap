#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/../lib/common.sh"

VERSION="1.1.0"

################
# Health Status
################

EXIT_CODE=0

WARNINGS=()
CRITICALS=()


#################
# Health Helpers
#################

add_warning() {

    WARNINGS+=("$1")

    if [[ "$EXIT_CODE" -lt 1 ]]; then
        EXIT_CODE=1
    fi

}

add_critical() {

    CRITICALS+=("$1")

    EXIT_CODE=2

}


check_pass() {

    printf "  %-30s : PASS\n" "$1"

}


check_warn() {

    printf "  %-30s : WARN\n" "$1"

}


check_fail() {

    printf "  %-30s : FAIL\n" "$1"

}


#######
# Help
#######

show_help() {

cat <<EOF

TANTO VPS Verification Module

Usage:

  sudo ./verify.sh [OPTION]

Options:

  --help, -h        Show this help message
  --version, -v     Show module version

Description:

  Performs read-only VPS health checks including:

    • Operating system
    • CPU and memory
    • Disk usage
    • Swap
    • SSH
    • Docker
    • Nginx
    • UFW firewall
    • Fail2Ban
    • Auditd
    • Unattended upgrades
    • Failed systemd services
    • Network connectivity
    • DNS resolution
    • Listening ports
    • Recent system errors

Exit codes:

  0                 Healthy
  1                 Healthy with warnings
  2                 Critical issues detected

Example:

  sudo ./verify.sh

EOF

}


##########
# Version
##########

show_version() {

    printf 'TANTO VPS Verification Module v%s\n' "$VERSION"

}


####################
# Service Detection
####################

detect_ssh_service() {

    if systemctl list-unit-files --type=service 2>/dev/null |
        grep -q '^ssh.service'; then

        printf 'ssh\n'

    elif systemctl list-unit-files --type=service 2>/dev/null |
        grep -q '^sshd.service'; then

        printf 'sshd\n'

    else

        return 1

    fi

}


#######################
# Service Verification
#######################

check_service() {

    local service="$1"
    local required="${2:-true}"

    if ! systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then

        if [[ "$required" == "true" ]]; then
            add_critical "${service} service is not installed"
            check_fail "${service} installed"
        else
            check_warn "${service} installed"
            add_warning "${service} service is not installed"
        fi

        return

    fi


    if systemctl is-active --quiet "$service"; then

        check_pass "${service} service"

    else

        if [[ "$required" == "true" ]]; then

            check_fail "${service} service"

            add_critical "${service} service is not running"

        else

            check_warn "${service} service"

            add_warning "${service} service is not running"

        fi

    fi

}


#####################
# System Information
#####################

system_information() {

    printf '\n'
    printf '%s\n' "=============================="
    printf '%s\n' "SYSTEM"
    printf '%s\n' "=============================="


    if [[ -f /etc/os-release ]]; then

        . /etc/os-release

        printf '  %-30s : %s\n' "Operating System" "${PRETTY_NAME:-Unknown}"

    fi


    printf '  %-30s : %s\n' "Hostname" "$(hostname)"

    printf '  %-30s : %s\n' "Kernel" "$(uname -r)"

    printf '  %-30s : %s\n' "Architecture" "$(uname -m)"

    printf '  %-30s : %s\n' "Uptime" "$(uptime -p)"


    if command -v nproc >/dev/null 2>&1; then

        printf '  %-30s : %s\n' "CPU Cores" "$(nproc)"

    fi

}


##################
# Resource Checks
##################

check_resources() {

    printf '\n'
    printf '%s\n' "=============================="
    printf '%s\n' "RESOURCES"
    printf '%s\n' "=============================="


    local memory_available
    local memory_total
    local memory_percentage
    local disk_usage


    memory_available=$(free | awk '/Mem:/ {print $7}')

    memory_total=$(free | awk '/Mem:/ {print $2}')


    if [[ "$memory_total" -gt 0 ]]; then

        memory_percentage=$((memory_available * 100 / memory_total))

        printf '  %-30s : %s%%\n' \
            "Available Memory" \
            "$memory_percentage"

        if (( memory_percentage < 10 )); then

            check_fail "Memory availability"

            add_critical "Available memory is below 10%"

        elif (( memory_percentage < 20 )); then

            check_warn "Memory availability"

            add_warning "Available memory is below 20%"

        else

            check_pass "Memory availability"

        fi

    fi


    disk_usage=$(df / | awk 'NR==2 {gsub("%",""); print $5}')

    printf '  %-30s : %s%%\n' "Root Disk Usage" "$disk_usage"


    if (( disk_usage >= 90 )); then

        check_fail "Disk usage"

        add_critical "Root disk usage is ${disk_usage}%"

    elif (( disk_usage >= 80 )); then

        check_warn "Disk usage"

        add_warning "Root disk usage is ${disk_usage}%"

    else

        check_pass "Disk usage"

    fi


    if swapon --show --noheadings 2>/dev/null | grep -q .; then

        check_pass "Swap"

    else

        check_warn "Swap"

        add_warning "No active swap detected"

    fi

}


#################
# Service Checks
#################

verify_services() {

    printf '\n'
    printf '%s\n' "=============================="
    printf '%s\n' "SERVICES"
    printf '%s\n' "=============================="


    local ssh_service


    if ssh_service=$(detect_ssh_service); then

        check_service "$ssh_service" true

    else

        check_fail "SSH service"

        add_critical "Unable to determine SSH service"

    fi


    if systemctl list-unit-files nginx.service >/dev/null 2>&1; then

        check_service nginx true

    else

        check_warn "Nginx service"

        add_warning "Nginx is not installed"

    fi


    if systemctl list-unit-files docker.service >/dev/null 2>&1; then

        check_service docker true

    else

        check_warn "Docker service"

        add_warning "Docker is not installed"

    fi


    if systemctl list-unit-files fail2ban.service >/dev/null 2>&1; then

        check_service fail2ban true

    else

        check_warn "Fail2Ban service"

        add_warning "Fail2Ban is not installed"

    fi


    if systemctl list-unit-files auditd.service >/dev/null 2>&1; then

        check_service auditd true

    else

        check_warn "Auditd service"

        add_warning "Auditd is not installed"

    fi


    if systemctl list-unit-files unattended-upgrades.service >/dev/null 2>&1; then

        check_service unattended-upgrades false

    else

        check_warn "Automatic updates"

        add_warning "Unattended upgrades are not installed"

    fi

}


#################
# Firewall Check
#################

verify_firewall() {

    printf '\n'
    printf '%s\n' "=============================="
    printf '%s\n' "FIREWALL"
    printf '%s\n' "=============================="


    if ! command -v ufw >/dev/null 2>&1; then

        check_fail "UFW"

        add_critical "UFW is not installed"

        return

    fi


    if ufw status | grep -q "Status: active"; then

        check_pass "UFW firewall"

        ufw status verbose

    else

        check_fail "UFW firewall"

        add_critical "UFW firewall is inactive"

        ufw status verbose || true

    fi

}


############
# SSH Check
############

verify_ssh_configuration() {

    printf '\n'
    printf '%s\n' "=============================="
    printf '%s\n' "SSH CONFIGURATION"
    printf '%s\n' "=============================="


    if ! command -v sshd >/dev/null 2>&1; then

        check_fail "sshd configuration"

        add_critical "sshd command is not available"

        return

    fi


    if sshd -t; then

        check_pass "SSH configuration"

    else

        check_fail "SSH configuration"

        add_critical "SSH configuration validation failed"

    fi

}


#########
# Docker
#########

verify_docker() {

    printf '\n'
    printf '%s\n' "=============================="
    printf '%s\n' "DOCKER"
    printf '%s\n' "=============================="


    if ! command -v docker >/dev/null 2>&1; then

        check_warn "Docker"

        add_warning "Docker is not installed"

        return

    fi


    if docker info >/dev/null 2>&1; then

        check_pass "Docker daemon"

    else

        check_fail "Docker daemon"

        add_critical "Docker daemon is unavailable"

        return

    fi


    printf '  %-30s : %s\n' \
        "Docker Version" \
        "$(docker --version)"


    if docker compose version >/dev/null 2>&1; then

        check_pass "Docker Compose"

    else

        check_warn "Docker Compose"

        add_warning "Docker Compose plugin is unavailable"

    fi


    if docker buildx version >/dev/null 2>&1; then

        check_pass "Docker Buildx"

    else

        check_warn "Docker Buildx"

        add_warning "Docker Buildx is unavailable"

    fi


    printf '\n'
    docker system df || true

}


##########
# Network
##########

verify_network() {

    printf '\n'
    printf '%s\n' "=============================="
    printf '%s\n' "NETWORK"
    printf '%s\n' "=============================="


    if ! command -v ip >/dev/null 2>&1; then

        check_warn "Network tools"

        add_warning "ip command is unavailable"

    else

        check_pass "Network tools"

    fi


    if command -v ping >/dev/null 2>&1; then

        if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then

            check_pass "Internet connectivity"

        else

            check_fail "Internet connectivity"

            add_critical "Unable to reach external network"

        fi

    else

        check_warn "Internet connectivity"

        add_warning "ping command is unavailable"

    fi


    if getent hosts github.com >/dev/null 2>&1; then

        check_pass "DNS resolution"

    else

        check_fail "DNS resolution"

        add_critical "DNS resolution failed"

    fi


    if command -v ss >/dev/null 2>&1; then

        printf '\n'
        printf '%s\n' "Listening Ports"
        printf '%s\n' "------------------------------"

        ss -tulpn

    else

        check_warn "Listening ports"

        add_warning "ss command is unavailable"

    fi

}


#######################
# Failed Systemd Units
#######################

verify_failed_services() {

    printf '\n'
    printf '%s\n' "=============================="
    printf '%s\n' "FAILED SYSTEMD UNITS"
    printf '%s\n' "=============================="


    local failed

    failed=$(systemctl --failed --no-legend 2>/dev/null | wc -l)


    if (( failed > 0 )); then

        check_warn "Failed systemd units"

        add_warning "${failed} failed systemd unit(s) detected"

        systemctl --failed --no-pager

    else

        check_pass "Failed systemd units"

        printf '  No failed systemd units detected.\n'

    fi

}


################
# Recent Errors
################

verify_logs() {

    printf '\n'
    printf '%s\n' "=============================="
    printf '%s\n' "RECENT SYSTEM ERRORS"
    printf '%s\n' "=============================="


    if ! command -v journalctl >/dev/null 2>&1; then

        check_warn "System journal"

        add_warning "journalctl is unavailable"

        return

    fi


    local errors

    errors=$(journalctl -p err -n 20 --no-pager 2>/dev/null || true)


    if [[ -n "$errors" ]]; then

        check_warn "Recent system errors"

        printf '%s\n' "$errors"

        add_warning "Recent system errors detected"

    else

        check_pass "Recent system errors"

        printf '  No recent system errors detected.\n'

    fi

}


#################
# Health Summary
#################

health_summary() {

    printf '\n'
    printf '%s\n' "======================================="
    printf '%s\n' "HEALTH SUMMARY"
    printf '%s\n' "======================================="


    printf '\n'
    printf 'Critical issues : %d\n' "${#CRITICALS[@]}"
    printf 'Warnings        : %d\n' "${#WARNINGS[@]}"


    if ((${#CRITICALS[@]})); then

        printf '\n'
        printf 'Critical Issues:\n'

        printf '  - %s\n' "${CRITICALS[@]}"

    fi


    if ((${#WARNINGS[@]})); then

        printf '\n'
        printf 'Warnings:\n'

        printf '  - %s\n' "${WARNINGS[@]}"

    fi


    printf '\n'


    case "$EXIT_CODE" in

        0)

            success "Overall Status: HEALTHY"

            ;;


        1)

            warn "Overall Status: HEALTHY WITH WARNINGS"

            ;;


        2)

            error "Overall Status: CRITICAL"

            ;;

    esac

}


########
# Main
########

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

            printf '\n'

            show_help

            exit 1

            ;;

    esac


    printf '\n'

    info "Starting TANTO VPS verification..."


    require_command systemctl
    require_command free
    require_command df
    require_command swapon
    require_command hostname
    require_command uname


    system_information

    check_resources

    verify_services

    verify_ssh_configuration

    verify_firewall

    verify_docker

    verify_network

    verify_failed_services

    verify_logs

    health_summary


    if [[ "$EXIT_CODE" -eq 0 ]]; then

        success "VPS verification completed successfully."

    elif [[ "$EXIT_CODE" -eq 1 ]]; then

        warn "VPS verification completed with warnings."

    else

        error "VPS verification detected critical issues."

    fi


    exit "$EXIT_CODE"

}


main "$@"
