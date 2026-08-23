#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/../lib/common.sh"

VERSION="1.0.0"

CONFIG_FILE="$(dirname "$0")/../config/defaults.conf"

load_config "$CONFIG_FILE"

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

##########
# Version
##########

show_version() {

    echo "Swap Configuration Module v${VERSION}"

}

###########################
# Configuration Validation
###########################

validate_configuration() {

    if ! [[ "${SWAP_SIZE_GB}" =~ ^[1-9][0-9]*$ ]]; then

        error "SWAP_SIZE_GB must be a positive integer."

        return 1

    fi

    if ! [[ "${VM_SWAPPINESS}" =~ ^[0-9]+$ ]] ||
       (( VM_SWAPPINESS < 0 || VM_SWAPPINESS > 100 )); then

        error "VM_SWAPPINESS must be between 0 and 100."

        return 1

    fi

    if ! [[ "${VM_VFS_CACHE_PRESSURE}" =~ ^[0-9]+$ ]] ||
       (( VM_VFS_CACHE_PRESSURE < 0 )); then

        error "VM_VFS_CACHE_PRESSURE must be a non-negative integer."

        return 1

    fi

}

#############
# Root Check
#############

check_existing_swap() {

    if swapon --show | grep -q "/"; then

        info "Swap is already configured."

        swapon --show

        exit 0

    fi

    info "No existing swap detected."
}

determine_swap_size() {

    SWAP_SIZE="${SWAP_SIZE_GB}G"

    info "Configured swap size: ${SWAP_SIZE}"

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

    cat >/etc/sysctl.d/99-tanto-vps-bootstrap.conf <<EOF
vm.swappiness=${VM_SWAPPINESS}
vm.vfs_cache_pressure=${VM_VFS_CACHE_PRESSURE}
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


#######
# Main
#######

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
    
    validate_configuration

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
