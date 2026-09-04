#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/../lib/common.sh"

VERSION="1.0.0"

CONFIG_FILE="$(dirname "$0")/../config/defaults.conf"

loaf_config "$CONFIG_FILE"

#######
# Help
#######

show_help() {

    cat <<EOF

Nginx Installation Module

Usage:

  sudo ./nginx.sh [OPTION]

Options:

  --help, -h        Show this help message
  --version, -v     Show module version

Description:

  Installs and configures Nginx by:

    • Installing Nginx package
    • Enabling Nginx service
    • Configuring firewall access
    • Applying the Nginx configuration
    • Validating configuration
    • Restarting the service
    • Verifying the installation

Example:

  sudo ./nginx.sh

EOF

}


##########
# Version
##########

show_version() {

    echo "Nginx Installation Module v${VERSION}"

}


################
# Install Nginx
################

install_nginx() {

    info "Installing Nginx..."

    require_command apt-get
    require_command systemctl

    run_command apt-get update

    run_command apt-get install -y nginx

    run_command systemctl enable nginx
    run_command systemctl start nginx

    info "Nginx package installed."

}


#####################
# Configure Firewall
#####################

configure_firewall() {

    if ! command -v ufw >/dev/null 2>&1; then

        warn "UFW is not installed. Skipping firewall configuration."

        return

    fi

    info "Allowing HTTP and HTTPS through UFW..."

    run_command ufw allow "Nginx Full"

}


#######################
# Configure nginx.conf
#######################

configure_nginx() {

    info "Configuring Nginx..."

    require_command cp
    require_command mkdir

    local config_file="/etc/nginx/nginx.conf"
    local backup_file

    if [[ ! -f "$config_file" ]]; then

        error "Nginx configuration file not found: ${config_file}"

        exit 1

    fi

    backup_file="${config_file}.bak.$(date '+%Y%m%d-%H%M%S')"

    run_command cp "$config_file" "$backup_file"

    info "Nginx configuration backup created: ${backup_file}"

    cat > "$config_file" <<'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 4096;
    multi_accept on;
}

http {

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    keepalive_timeout 65;

    server_tokens off;

    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    gzip on;
    gzip_comp_level 5;
    gzip_min_length 256;

    gzip_types
        text/plain
        text/css
        application/json
        application/javascript
        application/xml
        image/svg+xml;

    client_max_body_size 100M;

    add_header X-Frame-Options SAMEORIGIN always;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

    info "Nginx configuration applied."

}


##################
# Validate Nginx
##################

validate_nginx() {

    info "Validating Nginx configuration..."

    require_command nginx

    run_command nginx -t

}


##################
# Restart Nginx
##################

restart_nginx() {

    info "Restarting Nginx..."

    require_command systemctl

    run_command systemctl restart nginx

}


#################
# Verify Nginx
#################

verify_nginx() {

    info "Verifying Nginx..."

    require_command nginx
    require_command systemctl

    if ! systemctl is-active --quiet nginx; then

        error "Nginx service is not running."

        systemctl --no-pager --full status nginx || true

        exit 1

    fi

    nginx -v

    info "Nginx service is running."

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

    info "Starting Nginx installation..."

    install_nginx

    configure_firewall

    configure_nginx

    validate_nginx

    restart_nginx

    verify_nginx

    success "Nginx installation completed successfully."

}


main "$@"