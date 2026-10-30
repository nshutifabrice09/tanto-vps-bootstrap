#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/../lib/common.sh"

VERSION="1.0.0"

CONFIG_FILE="$(dirname "$0")/../config/defaults.conf"

load_config "$CONFIG_FILE"

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

################
# Configuration
################

BACKUP_DIR="/var/backups/vps"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

BACKUP_FILE="server-backup-${TIMESTAMP}.tar.gz"

#########################
# Validate Configuration
#########################

validate_configuration() {
    if ! [[ "${BACKUP_RETENTION_DAYS}" =~ ^[0-9]+$ ]]; then
        error "BACKUP_RETENTION_DAYS must be a non-negative integer."
        return 1
    fi

}

###########################
# Prepare Backup Directory
###########################

prepare_backup_directory() {

    info "Preparing backup directory..."

    install -d -m 700 "$BACKUP_DIR"

}

##############################
# Backup System Configuration
##############################

backup_system_files() {

    info "Backing up system configuration..."

    local temporary_archive
    temporary_archive="$(mktemp "${BACKUP_DIR}/.server-backup-${TIMESTAMP}.XXXXXX")"

    if ! tar -czf "$temporary_archive" -C / etc root home; then
        rm -f -- "$temporary_archive"
        error "System archive creation failed."
        return 1
    fi

    if ! tar -tzf "$temporary_archive" >/dev/null; then
        rm -f -- "$temporary_archive"
        error "System archive integrity check failed."
        return 1
    fi

    mv -f -- "$temporary_archive" "${BACKUP_DIR}/${BACKUP_FILE}"

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
        || { rm -f -- "${BACKUP_DIR}/postgres-${TIMESTAMP}.sql"; error "PostgreSQL backup failed."; return 1; }


    else

        warn "PostgreSQL not found. Skipping."

    fi



    if command -v mysqldump >/dev/null; then

        info "Backing up MySQL databases..."

        mysqldump \
        --all-databases \
        > "${BACKUP_DIR}/mysql-${TIMESTAMP}.sql" \
        || { rm -f -- "${BACKUP_DIR}/mysql-${TIMESTAMP}.sql"; error "MySQL backup failed."; return 1; }

    else

        warn "MySQL not found. Skipping."

    fi

}


#################
# Rotate Backups
#################

cleanup_old_backups() {

    info "Removing backups older than ${BACKUP_RETENTION_DAYS} days..."

    find "$BACKUP_DIR" \
        -type f \
        \( -name 'server-backup-*.tar.gz' \
        -o -name 'docker-containers-*.txt' \
        -o -name 'docker-images-*.txt' \
        -o -name 'postgres-*.sql' \
        -o -name 'mysql-*.sql' \) \
        -mtime +"${BACKUP_RETENTION_DAYS}" \
        -delete

}


###############
# Verification
###############

verify_backup() {

    info "Checking backup files..."

    [[ -s "${BACKUP_DIR}/${BACKUP_FILE}" ]] || {
        error "Expected system archive is missing or empty."
        return 1
    }

    tar -tzf "${BACKUP_DIR}/${BACKUP_FILE}" >/dev/null

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

    validate_configuration

    umask 077

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
