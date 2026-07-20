#!/sur/bin/env bash

set -Eeuo pipefail

###############################
# TANTO VPS BOOTSTAP INSTALLER
###############################

VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="${SCRIPT_DIR}/scripts"

##########
# LOGGING
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

#############
# ROOT CHECK
#############

require_root() {

    if [[ $EUID -ne 0 ]]; then

        error "This installer must be run as root."

        echo
        echo "Try:"
        echo "sudo ./install.sh <option>"

        exit 1

    fi

}


