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
