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