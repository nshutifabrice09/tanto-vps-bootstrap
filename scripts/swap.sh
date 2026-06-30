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

check_existing_swap() {

    if swapon --show | grep -q "/"; then

        info "Swap is already configured."

        swapon --show

        exit 0

    fi

    info "No existing swap detected."
}

determine_swap_size() {

    local total_ram_mb

    total_ram_mb=$(free -m | awk '/^Mem:/ {print $2}')

    if (( total_ram_mb <= 2048 )); then
        SWAP_SIZE="2G"

    elif (( total_ram_mb <= 4096 )); then
        SWAP_SIZE="4G"

    elif (( total_ram_mb <= 8192 )); then
        SWAP_SIZE="4G"

    else
        SWAP_SIZE="8G"
    fi

    info "Detected RAM: ${total_ram_mb} MB"
    info "Recommended swap size: ${SWAP_SIZE}"
}

create_swap_file() {

    info "Creating ${SWAP_SIZE} swap file..."

    fallocate -l "${SWAP_SIZE}" /swapfile

    chmod 600 /swapfile

    mkswap /swapfile

    swapon /swapfile

    info "Swap file created and enabled."
}


########
# Main
########

main() {

    info "Starting swap configuration..."

    require_root
    chech_existing_swap
    determine_swa_size
    create_Swap_file

    info "Swap configuration initialized."
}

main "$@"
