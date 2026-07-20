#!/usr/bin/env bash

set -Eeuo pipefail

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

    [[ $EXIT_CODE -lt 1 ]] && EXIT_CODE=1
}

add_critical() {

    CRITICALS+=("$1")

    EXIT_CODE=2
}


##########
# Logging
##########

info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

##########
# Helpers
##########

check_service() {

    local service="$1"
    local required="${2:-true}"

    if systemctl is-active --quiet "$service"; then

        printf "  %-20s : ✅ Running\n" "$service"

    else

        printf "  %-20s : ❌ Not running\n" "$service"

        if [[ "$required" == "true" ]]; then
            add_critical "$service service is not running"
        else
            add_warning "$service service is not running"
        fi

    fi
}

#####################
# System Information
#####################

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

###########
# Services
###########

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

#############
# Disk Usage
#############

check_disk_usage() {

    local usage

    usage=$(df / | awk 'NR==2 {gsub("%",""); print $5}')

    if (( usage >= 90 )); then

        add_critical "Disk usage is ${usage}%"

    elif (( usage >= 80 )); then

        add_warning "Disk usage is ${usage}%"

    fi

}

###############
# Memory Check
###############

check_memory() {

    local available

    available=$(free | awk '/Mem:/ {print int($7/$2*100)}')

    if (( available < 10 )); then

        add_critical "Available memory below 10%"

    elif (( available < 20 )); then

        add_warning "Available memory below 20%"

    fi

}


###########
# Firewall
###########

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

#########
# Docker
#########

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

##########
# Network
##########

verify_network() {

    echo
    echo "=============================="
    echo "LISTENING PORTS"
    echo "=============================="

    ss -tulpn
}

##################
# Failed Services
##################


verify_failed_services() {

    echo
    echo "=============================="
    echo "FAILED SYSTEMD UNITS"
    echo "=============================="

    local failed

    failed=$(systemctl --failed --no-legend | wc -l)

    if (( failed > 0 )); then

        add_warning "${failed} failed systemd unit(s) detected"

    fi

    systemctl --failed --no-pager

}

################
# Recent Errors
################

verify_logs() {

    echo
    echo "=============================="
    echo "RECENT SYSTEM ERRORS"
    echo "=============================="

    journalctl -p err -n 20 --no-pager

}

#################
# Health Summary
#################

health_summary() {

    echo
    echo "======================================="
    echo "Health Summary"
    echo "======================================="

    if ((${#CRITICALS[@]})); then

        echo
        echo "Critical Issues:"

        printf '  - %s\n' "${CRITICALS[@]}"

    fi

    if ((${#WARNINGS[@]})); then

        echo
        echo "Warnings:"

        printf '  - %s\n' "${WARNINGS[@]}"

    fi

    echo

    case "$EXIT_CODE" in
        0)
            echo "Overall Status : HEALTHY"
            ;;
        1)
            echo "Overall Status : HEALTHY WITH WARNINGS"
            ;;
        2)
            echo "Overall Status : CRITICAL"
            ;;
    esac
}

#######
# Main
#######

main() {

    info "Running VPS verification..."

    system_information

    verify_services

    check_disk_usage

    check_memory

    verify_firewall

    verify_docker

    verify_network

    verify_failed_services

    verify_logs

    health_summary

    info "Verification completed."

    exit "$EXIT_CODE"

}

main "$@"
