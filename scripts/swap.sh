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

########
# Main
########

main() {

    info "Starting swap configuration..."

    require_root

    info "Swap configuration initialized."
}

main "$@"
