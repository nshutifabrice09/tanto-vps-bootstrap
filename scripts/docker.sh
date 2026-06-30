#!/usr/bin/env bash

set -Eeuo pipefail

echo "[DOCKER] Starting Docker installation..."

info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

info "Starting Docker installation..."

if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root."
    exit 1
fi

remove_old_packages() {
    info "Removing conflicting Docker packages..."

    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        apt-get remove -y "$pkg" >/dev/null 2>&1 || true
    done
}

install_prerequisites() {
    info "Installing Docker prerequisites..."

    apt-get update

    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
}

main() {
    remove_old_packages
    install_prerequisites

    info "Docker prerequisites installed."
}

add_docker_repository() {
    info "Adding Docker APT repository..."

    ARCH=$(dpkg --print-architecture)
    CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")

    echo \
        "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update

    info "Docker repository added successfully."

}

main() {
    remove_old_packages
    install_prerequisites
    install_docker_gpg_key
    add_docker_repository

    info "Docker repository configured."
}

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

    info "Docker Engine installed successfully."
}

main "$@"
