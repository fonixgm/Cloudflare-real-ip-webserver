#!/bin/bash
# Simple bash script to restore visitor real IP under Cloudflare with Apache or Nginx
# Script also whitelists Cloudflare IP with UFW (if installed)

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." 
    exit 1
fi

# Set variables
CF_UFW_SETUP=""
WEB_SERVER=""

if [ "$1" = "--ufw" ]; then
    CF_UFW_SETUP="y"
fi

# Check for and install CURL if not present
if [ -z "$(command -v curl)" ]; then
    echo "####################################"
    echo "Installing CURL"
    echo "####################################"
    apt-get update && apt-get install curl -y
    if [ $? -ne 0 ]; then
        echo "Error: CURL installation failed."
        exit 1
    fi
fi

CURL_BIN=$(command -v curl)
CF_IPV4=$($CURL_BIN -sL https://www.cloudflare.com/ips-v4)
CF_IPV6=$($CURL_BIN -sL https://www.cloudflare.com/ips-v6)

# Detect the web server
if [ -n "$(command -v apache2)" ]; then
    WEB_SERVER="apache2"
    APACHE_CONF_DIR="/etc/apache2/conf-available"
elif [ -n "$(command -v nginx)" ]; then
    WEB_SERVER="nginx"
    NGINX_CONF_DIR="/etc/nginx/conf.d"
else
    echo "Error: Neither Apache nor Nginx found on the system."
    exit 1
fi

# Create and configure Cloudflare.conf
echo "####################################"
echo "Setting up Cloudflare IPs for $WEB_SERVER"
echo "####################################"

if [ "$WEB_SERVER" = "apache2" ]; then
    # Configure Apache
    echo '' > "$APACHE_CONF_DIR/cloudflare.conf"
    for cf_ip4 in $CF_IPV4; do
        echo "SetEnvIf CF-Connecting-IP \"$cf_ip4\" REAL_IP" >> "$APACHE_CONF_DIR/cloudflare.conf"
        [ "$CF_UFW_SETUP" = "y" ] && ufw allow from "$cf_ip4" to any port 80 && ufw allow from "$cf_ip4" to any port 443
    done

    for cf_ip6 in $CF_IPV6; do
        echo "SetEnvIf CF-Connecting-IP \"$cf_ip6\" REAL_IP" >> "$APACHE_CONF_DIR/cloudflare.conf"
        [ "$CF_UFW_SETUP" = "y" ] && ufw allow from "$cf_ip6" to any port 80 && ufw allow from "$cf_ip6" to any port 443
    done
else
    # Configure Nginx
    [ ! -d "$NGINX_CONF_DIR" ] && mkdir -p "$NGINX_CONF_DIR"
    echo '' > "$NGINX_CONF_DIR/cloudflare.conf"
    for cf_ip4 in $CF_IPV4; do
        echo "set_real_ip_from $cf_ip4;" >> "$NGINX_CONF_DIR/cloudflare.conf"
        [ "$CF_UFW_SETUP" = "y" ] && ufw allow from "$cf_ip4" to any port 80 && ufw allow from "$cf_ip4" to any port 443
    done

    for cf_ip6 in $CF_IPV6; do
        echo "set_real_ip_from $cf_ip6;" >> "$NGINX_CONF_DIR/cloudflare.conf"
        [ "$CF_UFW_SETUP" = "y" ] && ufw allow from "$cf_ip6" to any port 80 && ufw allow from "$cf_ip6" to any port 443
    done

    echo 'real_ip_header CF-Connecting-IP;' >> "$NGINX_CONF_DIR/cloudflare.conf"
fi

# Reload UFW if setup
[ "$CF_UFW_SETUP" = "y" ] && ufw reload

echo "####################################"
echo "Setup complete for $WEB_SERVER."
echo "####################################"
