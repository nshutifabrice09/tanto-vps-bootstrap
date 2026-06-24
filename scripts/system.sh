#!/bin/bash

echo "[SYSTEM] Updating packages..."

apt update
apt upgrade -y

apt install -y \
    curl \
    wget \
    git \
    unzip \
    htop \
    jq \
    vim
