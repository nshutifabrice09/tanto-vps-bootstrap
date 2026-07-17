#!/usr/bin/env bash

set -Eeuo pipefail

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

#############
# Root Check
#############

require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root."
        exit 1
    fi
}

################
# Install Nginx
################

install_nginx() {

    info "Installing Nginx..."

    apt-get update

    apt-get install -y nginx

    systemctl enable nginx

    systemctl start nginx
}

#####################
# Configure Firewall
#####################

configure_firewall() {

    if command -v ufw >/dev/null; then

        info "Allowing HTTP and HTTPS through UFW..."

        ufw allow "Nginx Full"

    else

        warn "UFW is not installed. Skipping firewall configuration."

    fi
}

#######################
# Configure nginx.conf
#######################

configure_nginx() {

    info "Configuring nginx..."

    cp /etc/nginx/nginx.conf \
       /etc/nginx/nginx.conf.bak

    cat >/etc/nginx/nginx.conf <<'EOF'
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

}

validate_nginx() {

    info "Validating nginx configuration..."

    nginx -t
}

restart_nginx() {

    info "Restarting nginx..."

    systemctl restart nginx
}

verify_nginx() {

    info "Verifying nginx..."

    systemctl --no-pager --full status nginx

    nginx -v
}


main() {

    info "Starting Nginx installation..."

    require_root

    install_nginx

    configure_firewall

    configure_nginx

    validate_nginx

    restart_nginx

    verify_nginx

    info "Nginx installed successfully."
}

main "$@"

