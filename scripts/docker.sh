#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/../lib/common.sh"

VERSION="1.0.0"

CONFIG_FILE="$(dirname "$0")/../config/defaults.conf"

load_config "$CONFIG_FILE"


#######
# HELP
#######

show_help() {

    cat <<EOF

Docker Installation Module

Usage:

  sudo ./docker.sh [OPTION]

Options:

  --help, -h       Show this help message
  --version, -v    Show module version

Example:

  sudo ./docker.sh

EOF

}


#########
# Version
#########

show_version() {

    echo "Docker Configuration Module v${VERSION}"

}


######################
# Remove Old Packages
######################

remove_old_packages() {

    info "Removing conflicting Docker packages..."

    require_command apt-get

    local packages=(
        docker.io
        docker-doc
        docker-compose
        docker-compose-v2
        podman-docker
        containerd
        runc
    )

    for package in "${packages[@]}"; do

        apt-get remove -y "$package" >/dev/null 2>&1 || true

    done

    info "Conflicting Docker packages removed."

}


########################
# Install Prerequisites
########################

install_prerequisites() {

    info "Installing Docker prerequisites..."

    require_command apt-get

    run_command apt-get update

    run_command apt-get install -y \
        ca-certificates \
        curl \
        gnupg

    info "Docker prerequisites installed."

}


#########################
# Install Docker GPG Key
#########################

install_docker_gpg_key() {

    info "Installing Docker GPG key..."

    require_command install
    require_command curl
    require_command gpg

    run_command install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor \
        -o /etc/apt/keyrings/docker.gpg

    run_command chmod a+r /etc/apt/keyrings/docker.gpg

    info "Docker GPG key installed."

}


########################
# Add Docker Repository
########################

add_docker_repository() {

    info "Adding Docker repository..."

    require_command dpkg
    require_command tee

    local arch
    local codename

    arch="$(dpkg --print-architecture)"
    codename="$(
        . /etc/os-release
        echo "$VERSION_CODENAME"
    )"

    if [[ -z "$codename" ]]; then

        error "Unable to determine Ubuntu release codename."

        exit 1

    fi

    echo \
        "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable" \
        | tee /etc/apt/sources.list.d/docker.list >/dev/null

    run_command apt-get update

    info "Docker repository configured."

}


#################
# Install Docker
#################

install_docker() {

    info "Installing Docker Engine..."

    require_command apt-get
    require_command systemctl

    run_command apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    run_command systemctl enable docker
    run_command systemctl start docker

    info "Docker Engine installed."

}


########################
# Configure Docker User
########################

configure_docker_user() {

    info "Configuring Docker user..."

    if [[ -z "${SUDO_USER:-}" ]]; then

        warn "Unable to determine the invoking user."
        warn "Docker group configuration skipped."

        return

    fi

    require_command id
    require_command usermod

    if id -nG "$SUDO_USER" | grep -qw docker; then

        info "User '$SUDO_USER' is already a member of the docker group."

    else

        run_command usermod -aG docker "$SUDO_USER"

        info "Added '$SUDO_USER' to the docker group."

        warn "Please log out and back in before using Docker without sudo."

    fi

}


##########################
# Configure Docker Daemon
##########################

configure_docker_daemon() {

    info "Configuring Docker daemon..."

    require_command mkdir
    require_command systemctl

    run_command mkdir -p /etc/docker

    cat > /etc/docker/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "5"
    },
    "live-restore": true,
    "features": {
        "buildkit": true
    }
}
EOF

    if command -v dockerd >/dev/null 2>&1; then

        info "Validating Docker daemon configuration..."

        dockerd \
            --validate \
            --config-file /etc/docker/daemon.json

    else

        warn "dockerd command not found. Skipping configuration validation."

    fi

    run_command systemctl restart docker

    info "Docker daemon configured."

}


######################
# Verify Installation
######################

verify_docker_installation() {

    info "Verifying Docker installation..."

    require_command docker

    docker --version
    docker compose version
    docker buildx version

    info "Testing Docker container execution..."

    docker run --rm hello-world

    info "Docker verification completed successfully."

}


#######
# MAIN
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

    info "Starting Docker installation..."

    remove_old_packages

    install_prerequisites

    install_docker_gpg_key

    add_docker_repository

    install_docker

    configure_docker_user

    configure_docker_daemon

    verify_docker_installation

    success "Docker installation completed successfully."

}


main "$@"