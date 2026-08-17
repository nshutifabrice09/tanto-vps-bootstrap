#!/usr/bin/env bash

set -Eeuo pipefail

##################
# Common Logging
##################

info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
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

        echo
        echo "Try:"
        echo "sudo $0"

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


#################
# Command Runner
#################

run_command() {

    info "Running: $*"

    "$@"

}


##################
# Success Message
##################

success() {

    printf '\033[32m[SUCCESS]\033[0m %s\n' "$*"

}
