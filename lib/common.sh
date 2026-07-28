#!/usr/bin/env bash

##################
# Common Logging
##################
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
# Root Check
#############

require_root() {

    if [[ $EUID -ne 0 ]]; then

        error "This script must be run as root."

        echo
        echo "Try:"
        echo "sudo $0"

        exit 1

    fi

}
