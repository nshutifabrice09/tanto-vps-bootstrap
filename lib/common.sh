#!/usr/bin/env bash

set -Eeuo pipefail

##################
# Common Logging
##################

info() {
    printf '\033[32m[INFO]\033[0m %s\n' "$*"
}

success() {
    printf '\033[32m[SUCCESS]\033[0m %s\n' "$*"
}

warn() {
    printf '\033[33m[WARN]\033[0m %s\n' "$*" >&2
}

error() {
    printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2
}


#############
# Root Check
#############

require_root() {

    if [[ "${EUID}" -ne 0 ]]; then

        error "This script must be run as root."

        printf '\n'
        printf 'Try: sudo %s\n' "${0##*/}"

        exit 1

    fi

}


#####################
# Command Validation
#####################

require_command() {

    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then

        error "Required command not found: ${command_name}"

        exit 1

    fi

}

#######################
# Configuration Loader
#######################

load_config() {

    local config_file="${1:-}"

    if [[ -z "$config_file" ]]; then
        error "Configuration file path was not provided."
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        error "Configuration file not found: ${config_file}"
        return 1
    fi

    if [[ ! -r "$config_file" ]]; then
        error "Configuration file is not readable: ${config_file}"
        return 1
    fi

    # shellcheck disable=SC1090
    source "$config_file"
}

###########################
# Configuration Validation
###########################

validate_config() {
    if [[ ! "${TANTO_VERSION:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "TANTO_VERSION must follow semantic versioning."
        return 1
    fi

    if ! timedatectl list-timezones 2>/dev/null | grep -qx "${TIMEZONE:-}"; then
        error "Invalid timezone configured: ${TIMEZONE:-}"
        return 1
    fi

    if [[ ! "${SWAP_SIZE_GB:-}" =~ ^[1-9][0-9]*$ ]]; then
        error "SWAP_SIZE_GB must be a positive integer."
        return 1
    fi

    if [[ ! "${VM_SWAPPINESS:-}" =~ ^[0-9]+$ ]] ||
       (( VM_SWAPPINESS < 0 || VM_SWAPPINESS > 100 )); then
        error "VM_SWAPPINESS must be between 0 and 100."
        return 1
    fi

    if [[ ! "${VM_VFS_CACHE_PRESSURE:-}" =~ ^[0-9]+$ ]]; then
        error "VM_VFS_CACHE_PRESSURE must be a non-negative integer."
        return 1
    fi

    if [[ "${SSH_PERMIT_ROOT_LOGIN:-}" != "yes" &&
          "${SSH_PERMIT_ROOT_LOGIN:-}" != "no" ]]; then
        error "SSH_PERMIT_ROOT_LOGIN must be yes or no."
        return 1
    fi

    if [[ "${SSH_PASSWORD_AUTHENTICATION:-}" != "yes" &&
          "${SSH_PASSWORD_AUTHENTICATION:-}" != "no" ]]; then
        error "SSH_PASSWORD_AUTHENTICATION must be yes or no."
        return 1
    fi

    if [[ "${SSH_X11_FORWARDING:-}" != "yes" &&
          "${SSH_X11_FORWARDING:-}" != "no" ]]; then
        error "SSH_X11_FORWARDING must be yes or no."
        return 1
    fi

    if [[ ! "${FAIL2BAN_MAXRETRY:-}" =~ ^[1-9][0-9]*$ ]]; then
        error "FAIL2BAN_MAXRETRY must be a positive integer."
        return 1
    fi

    if [[ ! "${DOCKER_LOG_MAX_FILES:-}" =~ ^[1-9][0-9]*$ ]]; then
        error "DOCKER_LOG_MAX_FILES must be a positive integer."
        return 1
    fi

    if [[ "${DOCKER_LIVE_RESTORE:-}" != "true" &&
          "${DOCKER_LIVE_RESTORE:-}" != "false" ]]; then
        error "DOCKER_LIVE_RESTORE must be true or false."
        return 1
    fi

    if [[ ! "${NGINX_WORKER_CONNECTIONS:-}" =~ ^[1-9][0-9]*$ ]]; then
        error "NGINX_WORKER_CONNECTIONS must be a positive integer."
        return 1
    fi

    if [[ ! "${NGINX_KEEPALIVE_TIMEOUT:-}" =~ ^[1-9][0-9]*$ ]]; then
        error "NGINX_KEEPALIVE_TIMEOUT must be a positive integer."
        return 1
    fi

    if [[ ! "${DISK_WARNING_THRESHOLD:-}" =~ ^[0-9]+$ ]] ||
       (( DISK_WARNING_THRESHOLD < 1 || DISK_WARNING_THRESHOLD > 99 )); then
        error "DISK_WARNING_THRESHOLD must be between 1 and 99."
        return 1
    fi

    if [[ ! "${DISK_CRITICAL_THRESHOLD:-}" =~ ^[0-9]+$ ]] ||
       (( DISK_CRITICAL_THRESHOLD < 1 || DISK_CRITICAL_THRESHOLD > 100 )); then
        error "DISK_CRITICAL_THRESHOLD must be between 1 and 100."
        return 1
    fi

    if (( DISK_WARNING_THRESHOLD >= DISK_CRITICAL_THRESHOLD )); then
        error "DISK_WARNING_THRESHOLD must be lower than DISK_CRITICAL_THRESHOLD."
        return 1
    fi

    if [[ ! "${MEMORY_WARNING_THRESHOLD:-}" =~ ^[0-9]+$ ]] ||
       (( MEMORY_WARNING_THRESHOLD < 1 || MEMORY_WARNING_THRESHOLD > 99 )); then
        error "MEMORY_WARNING_THRESHOLD must be between 1 and 99."
        return 1
    fi

    if [[ ! "${MEMORY_CRITICAL_THRESHOLD:-}" =~ ^[0-9]+$ ]] ||
       (( MEMORY_CRITICAL_THRESHOLD < 1 || MEMORY_CRITICAL_THRESHOLD > 100 )); then
        error "MEMORY_CRITICAL_THRESHOLD must be between 1 and 100."
        return 1
    fi

    if (( MEMORY_CRITICAL_THRESHOLD >= MEMORY_WARNING_THRESHOLD )); then
        error "MEMORY_CRITICAL_THRESHOLD must be lower than MEMORY_WARNING_THRESHOLD."
        return 1
    fi

    info "Configuration validation passed."
}