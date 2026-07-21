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


#############
# Root Check
#############

require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root."
        exit 1
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

    TIMEZONE="${1:-UTC}"

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

    info "Starting system bootstrap..."

    require_root

    update_system

    install_packages

    configure_timezone "${1:-UTC}"

    cleanup_system

    show_summary

    info "System bootstrap completed successfully."
}

main "$@"
