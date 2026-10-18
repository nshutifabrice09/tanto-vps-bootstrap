#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

source "${PROJECT_DIR}/lib/common.sh"

VERSION="1.0.0"
CONFIG_FILE="${PROJECT_DIR}/config/defaults.conf"
SWAP_FILE="/swapfile"
SYSCTL_FILE="/etc/sysctl.d/99-tanto-vps-bootstrap.conf"
FSTAB_FILE="/etc/fstab"

load_config "${CONFIG_FILE}"

########
# Help
########

show_help() {
    cat <<EOF

Swap Configuration Module

Usage:
  sudo ./install.sh --swap

Options:
  --help, -h        Show this help message
  --version, -v     Show module version

Description:
  Configures swap storage, persists its configuration,
  and applies kernel memory parameters.

EOF
}

##########
# Version
##########

show_version() {
    printf 'Swap Configuration Module v%s\n' "${VERSION}"
}

#################
# Required Tools
#################

check_dependencies() {
    local command_name

    for command_name in \
        awk \
        cmp \
        fallocate \
        free \
        grep \
        chmod \
        mkswap \
        swapon \
        swapoff \
        sysctl \
        truncate
    do
        require_command "${command_name}"
    done
}

################
# Swap Sizing
################

determine_swap_size() {
    SWAP_SIZE_BYTES=$((SWAP_SIZE_GB * 1024 * 1024 * 1024))

    info "Configured swap size: ${SWAP_SIZE_GB} GB"
}

####################
# Configure Swapfile
####################

configure_swap_file() {
    local current_size

    if [[ -e "${SWAP_FILE}" && ! -f "${SWAP_FILE}" ]]; then
        error "${SWAP_FILE} exists but is not a regular file."
        return 1
    fi

    if [[ -f "${SWAP_FILE}" ]]; then
        current_size="$(stat -c '%s' "${SWAP_FILE}")"

        if [[ "${current_size}" -ne "${SWAP_SIZE_BYTES}" ]]; then
            error "${SWAP_FILE} exists with a different size."
            error "Expected ${SWAP_SIZE_GB} GB; found ${current_size} bytes."
            error "Resize or replace the swap file manually before retrying."
            return 1
        fi

        chmod 600 "${SWAP_FILE}"

        if ! swapon --show --noheadings --raw --output NAME |
            grep -Fxq "${SWAP_FILE}"; then

            info "Activating existing swap file..."
            mkswap "${SWAP_FILE}"
            swapon "${SWAP_FILE}"
        else
            info "Configured swap file is already active."
        fi

        return 0
    fi

    info "Creating ${SWAP_SIZE_GB} GB swap file..."

    if ! fallocate -l "${SWAP_SIZE_BYTES}" "${SWAP_FILE}"; then
        error "Failed to allocate ${SWAP_FILE}."
        return 1
    fi

    chmod 600 "${SWAP_FILE}"

    if ! mkswap "${SWAP_FILE}"; then
        rm -f "${SWAP_FILE}"
        error "Failed to initialize swap file."
        return 1
    fi

    if ! swapon "${SWAP_FILE}"; then
        error "Failed to activate swap file."
        return 1
    fi

    success "Swap file created and activated."
}

########################
# Persist Swap in Fstab
########################

persist_swap() {
    local desired_entry="/swapfile none swap sw 0 0"
    local temp_file

    info "Checking persistent swap configuration..."

    if grep -Eq '^[[:space:]]*/swapfile([[:space:]]|$)' "${FSTAB_FILE}"; then
        if grep -Fxq "${desired_entry}" "${FSTAB_FILE}"; then
            info "Correct swap entry already exists in /etc/fstab."
            return 0
        fi

        error "An existing /swapfile entry in /etc/fstab differs from the expected entry."
        error "Review ${FSTAB_FILE} manually; no changes were made."
        return 1
    fi

    temp_file="$(mktemp)"

    if ! cat "${FSTAB_FILE}" > "${temp_file}" ||
       ! printf '%s\n' "${desired_entry}" >> "${temp_file}"; then
        rm -f "${temp_file}"
        error "Could not prepare the updated fstab."
        return 1
    fi

    if ! cat "${temp_file}" >> "${FSTAB_FILE}"; then
        rm -f "${temp_file}"
        error "Could not update ${FSTAB_FILE}."
        return 1
    fi

    rm -f "${temp_file}"

    success "Swap entry added to /etc/fstab."
}

############################
# Configure Kernel Parameters
############################

configure_kernel_parameters() {
    local temp_file

    temp_file="$(mktemp)"

    cat > "${temp_file}" <<EOF
vm.swappiness=${VM_SWAPPINESS}
vm.vfs_cache_pressure=${VM_VFS_CACHE_PRESSURE}
EOF

    if [[ -f "${SYSCTL_FILE}" ]] && cmp -s "${temp_file}" "${SYSCTL_FILE}"; then
        info "Kernel parameter configuration is already current."
        rm -f "${temp_file}"
    else
        info "Updating kernel parameter configuration..."

        if ! install -m 644 "${temp_file}" "${SYSCTL_FILE}"; then
            rm -f "${temp_file}"
            error "Failed to install kernel parameter configuration."
            return 1
        fi

        rm -f "${temp_file}"

        info "Applying kernel parameters..."
        sysctl -p "${SYSCTL_FILE}"
        success "Kernel parameters updated."
    fi
}

#####################
# Verify Configuration
#####################

verify_swap_configuration() {
    local actual_size
    local active_swap
    local actual_swappiness
    local actual_cache_pressure

    info "Verifying swap configuration..."

    if ! swapon --show --noheadings --raw --output NAME |
        grep -Fxq "${SWAP_FILE}"; then
        error "${SWAP_FILE} is not active."
        return 1
    fi

    actual_size="$(stat -c '%s' "${SWAP_FILE}")"

    if [[ "${actual_size}" -ne "${SWAP_SIZE_BYTES}" ]]; then
        error "Swap file size does not match configuration."
        return 1
    fi

    actual_swappiness="$(sysctl -n vm.swappiness)"
    actual_cache_pressure="$(sysctl -n vm.vfs_cache_pressure)"

    if [[ "${actual_swappiness}" != "${VM_SWAPPINESS}" ]]; then
        error "vm.swappiness does not match configuration."
        return 1
    fi

    if [[ "${actual_cache_pressure}" != "${VM_VFS_CACHE_PRESSURE}" ]]; then
        error "vm.vfs_cache_pressure does not match configuration."
        return 1
    fi

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

    success "Swap configuration verified."
}

#######
# Main
#######

main() {
    case "${1:-}" in
        --help|-h)
            show_help
            return 0
            ;;
        --version|-v)
            show_version
            return 0
            ;;
        "")
            ;;
        *)
            error "Unknown option: $1"
            show_help
            return 1
            ;;
    esac

    require_root
    check_dependencies

    info "Validating configuration..."
    validate_config

    determine_swap_size

    info "Starting swap configuration..."

    configure_swap_file
    persist_swap
    configure_kernel_parameters
    verify_swap_configuration

    success "Swap configuration completed successfully."
}

main "$@"
