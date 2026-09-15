#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/../lib/common.sh"

VERSION="1.0.0"

CONFIG_FILE="$(dirname "$0")/../config/defaults.conf"

load_config "$CONFIG_FILE"

############
# Help
############

show_help() {

cat <<EOF

System Bootstrap Module

Usage:

sudo ./system.sh [OPTION]

Options:

  --help, -h        Show this help message
  --version, -v     Show module version

Description:

  Prepares a fresh Ubuntu server by:
    • Updating package indexes
    • Upgrading installed packages
    • Installing common utilities
    • Configuring timezone and locale (if applicable)

Example:

  sudo ./system.sh

EOF

}

##########
# Version
##########

show_version() {

    echo "System Bootstrap Module v${VERSION}"

}

########################
#Validate Configuration
########################
validate_configuration() {

    if ! timedatectl list-timezones | grep -qx "$TIMEZONE"; then

        error "Invalid timezone configured: ${TIMEZONE}"

        return 1

    fi

}

################
# Update System
################

update_system() {

    info "Updating package lists..."

    apt-get update

    info "Upgrading installed packages..."

    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
}

#############################
# Install Essential Packages
#############################

install_packages() {

    info "Installing essential packages..."

    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        wget \
        git \
        unzip \
        zip \
        vim \
        nano \
        htop \
        jq \
        tree \
        rsync \
        software-properties-common \
        gnupg \
        lsb-release \
        net-tools \
        dnsutils
}

#####################
# Configure Timezone
#####################

configure_timezone() {

    info "Setting timezone to ${TIMEZONE}..."

    timedatectl set-timezone "${TIMEZONE}"
}

##########
# Cleanup
##########

cleanup_system() {

    info "Cleaning unused packages..."

    apt-get autoremove -y

    apt-get autoclean -y
}

##########
# Summary
##########

show_summary() {

    echo
    echo "=============================="
    echo " System Information"
    echo "=============================="

    hostnamectl

    echo
    free -h

    echo
    df -h /

    echo
    timedatectl
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

    info "Starting system bootstrap..."

    update_system

    install_packages

    configure_timezone

    cleanup_system

    show_summary

    info "System bootstrap completed successfully."
}

main "$@"
