#!/usr/bin/env bash

set -Eeuo pipefail

VERSION="1.0.0"

################
# Configuration
################

JOURNAL_RETENTION="${JOURNAL_RETENTION:-14d}"
TEMP_RETENTION_DAYS="${TEMP_RETENTION_DAYS:-3}"
DOCKER_RETENTION_DAYS="${DOCKER_RETENTION_DAYS:-7}"

DRY_RUN=false


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

#######
# Help
#######

show_help() {

cat <<EOF

Cleanup Module

Usage:

sudo ./cleanup.sh [OPTION]

Options:

  --help, -h        Show this help message
  --version, -v     Show module version

Description:

  Cleans unnecessary VPS resources by:

    • Removing unused packages
    • Cleaning apt cache
    • Removing old temporary files
    • Cleaning Docker resources
    • Checking disk usage

Example:

  sudo ./cleanup.sh

EOF

}

##########
# Version
##########

show_version() {

    echo "Cleanup Module v${VERSION}"

}


############
# Arguments
############

parse_arguments() {

    while [[ $# -gt 0 ]]; do

        case "$1" in

            --help|-h)
                show_help
                exit 0
                ;;

            --version|-v)
                show_version
                exit 0
                ;;

            --dry-run)
                DRY_RUN=true
                shift
                ;;

            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;

        esac

    done

}


#############
# Root Check
#############

require_root() {

    if [[ $EUID -ne 0 ]]; then

        error "This script must be run as root."

        echo
        echo "Try:"
        echo "sudo ./cleanup.sh"

        exit 1

    fi

}


##########
# Helpers
##########

run_command() {

    if [[ "$DRY_RUN" == true ]]; then

        echo "[DRY-RUN] $*"

    else

        "$@"

    fi

}


##############
# Disk Report
##############

get_disk_usage() {

    df --output=used / | awk 'NR==2 {print $1}'

}


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

    run_command apt-get autoremove -y

    run_command apt-get autoclean -y

    run_command apt-get clean

}


##################
# Journal Cleanup
##################

cleanup_journal() {

    info "Cleaning system journal older than ${JOURNAL_RETENTION}..."

    run_command journalctl \
        --vacuum-time="${JOURNAL_RETENTION}"

}


##########################
# Temporary Files Cleanup
##########################

cleanup_temp() {

    info "Cleaning temporary files older than ${TEMP_RETENTION_DAYS} days..."

    run_command find /tmp \
        -mindepth 1 \
        -mtime +"${TEMP_RETENTION_DAYS}" \
        -delete


    run_command find /var/tmp \
        -mindepth 1 \
        -mtime +"${TEMP_RETENTION_DAYS}" \
        -delete

}


################
# Crash Reports
################

cleanup_crash_reports() {

    info "Removing crash reports..."

    run_command find /var/crash \
        -type f \
        -delete

}


#################
# Docker Cleanup
#################

cleanup_docker() {

    if ! command -v docker >/dev/null; then

        warn "Docker not installed. Skipping Docker cleanup."

        return

    fi


    info "Cleaning Docker resources older than ${DOCKER_RETENTION_DAYS} days..."

    run_command docker system prune \
        -af \
        --filter "until=${DOCKER_RETENTION_DAYS}d"

}


##########
# Summary
##########

show_summary() {

    local before="$1"
    local after="$2"


    echo
    echo "=============================="
    echo "Cleanup Summary"
    echo "=============================="


    echo "Disk before: ${before} KB"

    echo "Disk after : ${after} KB"


    if (( before > after )); then

        echo "Recovered : $((before-after)) KB"

    else

        echo "Recovered : 0 KB"

    fi

}

##################
# Confirm Cleanup
##################

confirm_cleanup() {

    read -r -p "Continue with cleanup? [y/N]: " response

    case "$response" in

        y|Y)
            return 0
            ;;

        *)
            info "Cleanup cancelled."
            exit 0
            ;;

    esac

}


#######
# Main
#######

main() {

    parse_arguments "$@"

    require_root

    confirm_cleanup

    info "Starting cleanup process..."

    local before
    local after

    before=$(get_disk_usage)

    cleanup_apt

    cleanup_journal

    cleanup_temp

    cleanup_crash_reports

    cleanup_docker

    after=$(get_disk_usage)

    show_disk_usage

    show_summary "$before" "$after"

    info "Cleanup completed successfully."

}

main "$@"
