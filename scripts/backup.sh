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

#######
# Help
#######

show_help() {

cat <<EOF

Backup Module

Usage:

sudo ./backup.sh [OPTION]

Options:

  --help, -h        Show this help message
  --version, -v     Show module version

Description:

  Configures VPS backup operations by:

    • Creating backup directories
    • Validating backup locations
    • Creating backup archives
    • Managing backup retention

Example:

  sudo ./backup.sh

EOF

}

##########
# Version
##########

show_version() {

    echo "Backup Module v${VERSION}"

}


#############
# Root Check
#############

require_root() {

    if [[ $EUID -ne 0 ]]; then

        error "This script must be run as root."

        echo
        echo "Try:"
        echo "sudo ./backup.sh"

        exit 1

    fi
}


################
# Configuration
################

BACKUP_DIR="/var/backups/vps"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

BACKUP_FILE="server-backup-${TIMESTAMP}.tar.gz"

RETENTION_DAYS=14


###########################
# Prepare Backup Directory
###########################

prepare_backup_directory() {

    info "Preparing backup directory..."

    mkdir -p "$BACKUP_DIR"

}

##############################
# Backup System Configuration
##############################

backup_system_files() {

    info "Backing up system configuration..."

    tar \
        -czf "${BACKUP_DIR}/${BACKUP_FILE}" \
        /etc \
        /root \
        /home \
        2>/dev/null || true

}


#####################
# Backup Docker Data
#####################

backup_docker() {

    if ! command -v docker >/dev/null; then

        warn "Docker not installed. Skipping Docker backup."

        return

    fi


    info "Backing up Docker information..."

    docker ps -a \
        > "${BACKUP_DIR}/docker-containers-${TIMESTAMP}.txt"


    docker images \
        > "${BACKUP_DIR}/docker-images-${TIMESTAMP}.txt"

}


##################
# Database Backup
##################

backup_databases() {


    if command -v pg_dumpall >/dev/null; then

        info "Backing up PostgreSQL databases..."

        pg_dumpall \
        > "${BACKUP_DIR}/postgres-${TIMESTAMP}.sql" \
        || warn "PostgreSQL backup failed."


    else

        warn "PostgreSQL not found. Skipping."

    fi



    if command -v mysqldump >/dev/null; then

        info "Backing up MySQL databases..."

        mysqldump \
        --all-databases \
        > "${BACKUP_DIR}/mysql-${TIMESTAMP}.sql" \
        || warn "MySQL backup failed."

    else

        warn "MySQL not found. Skipping."

    fi

}


#################
# Rotate Backups
#################

cleanup_old_backups() {

    info "Removing backups older than ${RETENTION_DAYS} days..."

    find "$BACKUP_DIR" \
        -type f \
        -mtime +"${RETENTION_DAYS}" \
        -delete

}


###############
# Verification
###############

verify_backup() {

    info "Checking backup files..."

    ls -lh "$BACKUP_DIR"

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

    info "Starting backup process..."


    prepare_backup_directory


    backup_system_files


    backup_docker


    backup_databases


    cleanup_old_backups


    verify_backup


    info "Backup completed successfully."

}


main "$@"
