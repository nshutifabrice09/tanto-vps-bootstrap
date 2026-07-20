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

#########
# BANNER
#########

show_banner() {

cat <<EOF

=================================
       TANTO VPS Bootstrap
=================================

Version: ${VERSION}

EOF

}

########
# HELP
########

show_help() {

cat <<EOF

Usage:

sudo ./install.sh [OPTION]


Options:

  --full              Run complete VPS bootstrap
  --system            Configure base system
  --security          Apply security hardening
  --swap              Configure swap memory
  --docker            Install Docker
  --nginx             Install and configure Nginx
  --tailscale         Configure Tailscale
  --backup            Configure backups
  --verify            Run VPS health check
  --cleanup           Cleanup system resources

  --help              Show this help message
  --version           Show installer version


Examples:

  sudo ./install.sh --full

  sudo ./install.sh --docker

  sudo ./install.sh --verify


EOF

}

################
# MODULE RUNNER
################

run_module() {

    local module="$1"

    local script="${MODULE_DIR}/${module}.sh"


    if [[ ! -f "$script" ]]; then

        error "Module not found: ${script}"

        exit 1

    fi


    info "Running ${module}.sh..."


    bash "$script"


    info "${module}.sh completed successfully."

}

####################
# FULL INSTALLATION
####################

run_full_installation() {

    info "Starting full VPS bootstrap..."


    local modules=(
        system
        security
        swap
        docker
        nginx
        tailscale
    )


    for module in "${modules[@]}"; do

        run_module "$module"

    done


    info "Full VPS bootstrap completed successfully."

}


