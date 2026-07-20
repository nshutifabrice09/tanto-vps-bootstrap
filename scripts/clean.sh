#!/usr/bin/env bash

set -Eeuo pipefail

##########
# Logging
##########

info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

#############
# Root Check
#############

require_root() {

    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root."
        exit 1
    fi

}

#############
# Disk Usage
#############

show_disk_usage() {

    echo
    echo "=============================="
    echo "Disk Usage"
    echo "=============================="

    df -h /

}

##############
# APT Cleanup
##############

cleanup_apt() {

    info "Cleaning APT packages..."

    apt-get autoremove -y

    apt-get autoclean -y

    apt-get clean

}

##################
# Journal Cleanup
##################

cleanup_journal() {

    info "Cleaning systemd journal..."

    journalctl --vacuum-time=14d

}

##################
# Temporary Files
##################

cleanup_temp() {

    info "Cleaning temporary files..."

    rm -rf /tmp/*

    rm -rf /var/tmp/*

}

################
# Crash Reports
################

cleanup_crash_reports() {

    info "Removing old crash reports..."

    rm -f /var/crash/*

}

#################
# Docker Cleanup
#################

cleanup_docker() {

    if ! command -v docker >/dev/null; then

        warn "Docker not installed. Skipping."

        return

    fi

    info "Cleaning unused Docker resources..."

    docker system prune -af

}

##########
# Summary
##########

show_summary() {

    echo
    echo "=============================="
    echo "Cleanup Complete"
    echo "=============================="

    df -h /

}

#######
# Main
#######

main() {

    info "Starting system cleanup..."

    require_root

    show_disk_usage

    cleanup_apt

    cleanup_journal

    cleanup_temp

    cleanup_crash_reports

    cleanup_docker

    show_summary

    info "Cleanup completed successfully."

}

main "$@"
