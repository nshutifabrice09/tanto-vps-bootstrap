#!/usr/bin/env bash

set -Eeuo pipefail

VERSION="1.0.0"

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

Swap Configuration Module

Usage:

sudo ./swap.sh [OPTION]

Options:

  --help, -h        Show this help message
  --version, -v     Show module version

Description:

  Creates and configures a Linux swap file by:

    • Checking if swap already exists
    • Creating a swap file
    • Setting secure permissions
    • Enabling swap
    • Persisting configuration in /etc/fstab
    • Optimizing vm.swappiness and vm.vfs_cache_pressure

Example:

  sudo ./swap.sh

EOF

}

#########
# Version
#########

show_version() {

    echo "Swap Configuration Module v${VERSION}"

}

#############
# Root Check
#############

require_root() {

    if [[ $EUID -ne 0 ]]; then

        error "This script must be run as root."

        echo
        echo "Try:"
        echo "sudo ./swap.sh"

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

    # Allow the user to specify a custom swap size.
    if [[ $# -ge 1 ]]; then
        SWAP_SIZE="$1"

        info "Using user-defined swap size: ${SWAP_SIZE}"

        return
    fi

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
    info "Automatically selected swap size: ${SWAP_SIZE}"
}

create_swap_file() {

    if [[ -f /swapfile ]]; then

        warn "/swapfile already exists."

        if ! swapon --show | grep -q "/swapfile"; then

            info "Activating existing swap file..."

            swapon /swapfile

        fi

        return

    fi

    info "Creating ${SWAP_SIZE} swap file..."

    fallocate -l "${SWAP_SIZE}" /swapfile

    chmod 600 /swapfile

    mkswap /swapfile

    swapon /swapfile

    info "Swap file created and enabled."
}


persist_swap() {

    info "Persisting swap configuration..."

    if grep -q "^/swapfile" /etc/fstab; then

        info "/swapfile already exists in /etc/fstab."

        return

    fi

    echo "/swapfile none swap sw 0 0" >> /etc/fstab

    info "Swap added to /etc/fstab."
}

configure_kernel_parameters() {

    info "Configuring kernel memory parameters..."

    cat >/etc/sysctl.d/99-gc-vps-bootstrap.conf <<EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF

    sysctl --system >/dev/null

    info "Kernel parameters configured."
}

verify_swap_configuration() {

    info "Verifying swap configuration..."

    echo
    echo "========== Memory =========="
    free -h

    echo
    echo "========== Active Swap =========="
    swapon --show

    echo
    echo "========== Kernel Parameters =========="
    sysctl vm.swappiness
    sysctl vm.vfs_cache_pressure

    info "Swap configuration verified successfully."
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
            echo
            show_help
            exit 1
            ;;

    esac


    require_root


    info "Starting swap configuration..."


    check_existing_swap

    determine_swap_size

    create_swap_file

    persist_swap

    configure_kernel_parameters

    verify_swap_configuration


    info "Swap configuration completed successfully."

}

main "$@"
