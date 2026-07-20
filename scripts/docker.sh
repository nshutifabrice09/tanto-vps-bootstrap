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

#######
# HELP
######

show_help() {

cat <<EOF

Docker Installation Script

Usage:

sudo ./docker.sh [OPTION]


Options:

  --help       Show this help message
  --version    Show script version


Example:

  sudo ./docker.sh

EOF

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

######################
# Remove Old Packages
######################

remove_old_packages() {

    info "Removing conflicting Docker packages..."

    for pkg in \
        docker.io \
        docker-doc \
        docker-compose \
        docker-compose-v2 \
        podman-docker \
        containerd \
        runc
    do
        apt-get remove -y "$pkg" >/dev/null 2>&1 || true
    done
}

########################
# Install Prerequisites
########################

install_prerequisites() {

    info "Installing Docker prerequisites..."

    apt-get update

    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
}

#########################
# Install Docker GPG Key
#########################

install_docker_gpg_key() {

    info "Installing Docker GPG key..."

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor \
        -o /etc/apt/keyrings/docker.gpg

    chmod a+r /etc/apt/keyrings/docker.gpg

    info "Docker GPG key installed."
}

########################
# Add Docker Repository
########################

add_docker_repository() {

    info "Adding Docker repository..."

    ARCH=$(dpkg --print-architecture)
    CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")

    echo \
        "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
        | tee /etc/apt/sources.list.d/docker.list >/dev/null

    apt-get update

    info "Docker repository configured."
}

#################
# Install Docker
#################

install_docker() {

    info "Installing Docker Engine..."

    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    info "Docker installed successfully."
}

########################
# Configure Docker User
########################

configure_docker_user() {

    info "Configuring Docker user..."

    if [[ -z "${SUDO_USER:-}" ]]; then
        warn "Unable to determine the invoking user."

        return
    fi

    if id -nG "$SUDO_USER" | grep -qw docker; then

        info "User '$SUDO_USER' is already a member of the docker group."

    else

        usermod -aG docker "$SUDO_USER"

        info "Added '$SUDO_USER' to the docker group."

        warn "Please log out and back in before using Docker without sudo."

    fi
}

##########################
# Configure Docker Daemon
##########################

configure_docker_daemon() {

    info "Configuring Docker daemon..."

    mkdir -p /etc/docker

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

    if command -v dockerd >/dev/null; then
        dockerd --validate --config-file /etc/docker/daemon.json
    fi

    systemctl restart docker

    info "Docker daemon configured."
}

######################
# Verify Installation
######################

verify_docker_installation() {

    info "Verifying Docker installation..."

    docker --version
    docker compose version
    docker buildx version

    docker run --rm hello-world

    info "Docker verification completed successfully."
}

#######
# Main
#######

main() {

    case "${1:-}" in

        --help)

            show_help
            exit 0
            ;;


        --version)

            echo "Docker installer version 1.0.0"
            exit 0
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


    info "Docker installation completed successfully."

}

main "$@"
