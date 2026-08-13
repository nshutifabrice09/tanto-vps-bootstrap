#!/usr/bin/env bash

set -Eeuo pipefail

###############################
# TANTO VPS BOOTSTRAP INSTALLER
###############################

VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="${SCRIPT_DIR}/scripts"

# Load shared functions
source "${SCRIPT_DIR}/lib/common.sh"


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

  --help, -h          Show this help message
  --version, -v       Show installer version


Examples:

  sudo ./install.sh --full

  sudo ./install.sh --docker

  sudo ./install.sh --verify

  sudo ./install.sh --cleanup

EOF

}


###########
# VERSION
###########

show_version() {

    echo "TANTO VPS Bootstrap v${VERSION}"

}


################
# MODULE CHECK
################

check_module() {

    local module="$1"
    local script="${MODULE_DIR}/${module}.sh"

    if [[ ! -f "$script" ]]; then

        error "Module not found: ${script}"

        return 1

    fi

    if [[ ! -r "$script" ]]; then

        error "Module is not readable: ${script}"

        return 1

    fi

}


################
# MODULE RUNNER
################

run_module() {

    local module="$1"
    local script="${MODULE_DIR}/${module}.sh"

    check_module "$module"

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
        backup
        verify
    )

    for module in "${modules[@]}"; do

        run_module "$module"

    done

    info "Full VPS bootstrap completed successfully."

}


#############
# ARGUMENTS
#############

parse_arguments() {

    if [[ $# -eq 0 ]]; then

        warn "No option provided."

        show_help

        exit 1

    fi

    if [[ $# -gt 1 ]]; then

        error "Only one option can be provided at a time."

        echo

        show_help

        exit 1

    fi

    case "$1" in

        --help|-h)

            show_help
            exit 0
            ;;

        --version|-v)

            show_version
            exit 0
            ;;

        --full|\
        --system|\
        --security|\
        --swap|\
        --docker|\
        --nginx|\
        --tailscale|\
        --backup|\
        --verify|\
        --cleanup)

            return 0
            ;;

        *)

            error "Unknown option: $1"

            echo

            show_help

            exit 1
            ;;

    esac

}

#######
# MAIN
#######

main() {

    show_banner

    local action

    if parse_arguments "$@"; then
        exit 0
    else
        action=$?
    fi

    # parse_arguments returns 2 when an actual action
    # requires execution.
    if [[ "$action" -ne 2 ]]; then
        exit "$action"
    fi

    require_root

    case "$1" in

        --full)

            run_full_installation

            ;;

        --system)

            run_module system

            ;;

        --security)

            run_module security

            ;;

        --swap)

            run_module swap

            ;;

        --docker)

            run_module docker

            ;;

        --nginx)

            run_module nginx

            ;;

        --tailscale)

            run_module tailscale

            ;;

        --backup)

            run_module backup

            ;;

        --verify)

            run_module verify

            ;;

        --cleanup)

            run_module cleanup

            ;;

    esac

}


##########
# EXECUTE
##########

main "$@"
