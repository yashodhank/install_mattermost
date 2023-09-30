#!/bin/bash

set -e

function install_mattermost() {
    echo "Installing Mattermost..."

    read -p "Choose installation method (package/archive): " install_method
    read -p "Enter your domain name (or leave empty if not applicable): " domain_name
    read -p "Enable SSL? (yes/no): " enable_ssl

    mm_db_pass=$(openssl rand -base64 32)

    apt update && apt upgrade -y
    apt install -y sudo curl wget gnupg postgresql nginx jq

    sudo -u postgres psql -c "CREATE DATABASE mattermost"
    sudo -u postgres psql -c "CREATE USER mmuser WITH PASSWORD '$mm_db_pass'"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mattermost to mmuser"

    if [ "$install_method" == "package" ]; then
        curl -o- https://deb.packages.mattermost.com/repo-setup.sh | sudo bash -s mattermost
        sudo apt install mattermost -y
        # Check if the mattermost group exists, and create it if it doesn't
        if ! getent group mattermost > /dev/null; then
            sudo addgroup --system mattermost
        fi
        
        # Check if the mattermost user exists, and create it if it doesn't
        if ! id -u mattermost > /dev/null 2>&1; then
            sudo adduser --system --ingroup mattermost --no-create-home --disabled-login --disabled-password --gecos "" mattermost
        fi
        # Now you can safely run the install command
        sudo install -C -m 600 -o mattermost -g mattermost /opt/mattermost/config/config.defaults.json /opt/mattermost/config/config.json
    else
        wget $(curl -s https://api.github.com/repos/mattermost/mattermost-server/releases/latest | grep browser_download_url | cut -d '"' -f 4 | grep -E 'linux-amd64.tar.gz$') -O mattermost.tar.gz
        tar -xzf mattermost.tar.gz -C /opt
        mkdir /opt/mattermost/data
        cp /opt/mattermost/config/config.default.json /opt/mattermost/config/config.json
        # Check if the mattermost group exists, and create it if it doesn't
        if ! getent group mattermost > /dev/null; then
            addgroup --gid ${PGID:-1000} mattermost
        fi
        
        # Check if the mattermost user exists, and create it if it doesn't
        if ! id -u mattermost > /dev/null 2>&1; then
            adduser -q --disabled-password --uid ${PUID:-1000} --gid ${PGID:-1000} --gecos "" --home /opt/mattermost mattermost
        fi
    fi

    protocol="http://"
    if [ "$enable_ssl" == "yes" ]; then
        protocol="https://"
    fi

    jq '.ServiceSettings.SiteURL = "'${protocol}${domain_name}'" | .SqlSettings.DriverName = "postgres" | .SqlSettings.DataSource = "postgres://mmuser:'${mm_db_pass}'@localhost:5432/mattermost?sslmode=disable&connect_timeout=10"' /opt/mattermost/config/config.json > /tmp/config.json && mv /tmp/config.json /opt/mattermost/config/config.json
    
    # Set the owner and permissions for the Mattermost directory and configuration file
    chown -Rf mattermost:mattermost /opt/mattermost
    chmod -R 600 /opt/mattermost/config/config.json

    systemctl start mattermost
    systemctl enable mattermost

    if [ "$enable_ssl" == "yes" ]; then
        apt install -y certbot python3-certbot-nginx

        if certbot --nginx -d $domain_name; then
            jq '.ServiceSettings.ConnectionSecurity = "TLS" | .ServiceSettings.TLSCertFile = "/etc/letsencrypt/live/'${domain_name}'/fullchain.pem" | .ServiceSettings.TLSKeyFile = "/etc/letsencrypt/live/'${domain_name}'/privkey.pem"' /opt/mattermost/config/config.json > /tmp/config.json && mv /tmp/config.json /opt/mattermost/config/config.json
        else
            openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout /opt/mattermost/config/key.pem -out /opt/mattermost/config/cert.pem -subj "/CN=$domain_name"
            jq '.ServiceSettings.ConnectionSecurity = "TLS" | .ServiceSettings.TLSCertFile = "/opt/mattermost/config/cert.pem" | .ServiceSettings.TLSKeyFile = "/opt/mattermost/config/key.pem"' /opt/mattermost/config/config.json > /tmp/config.json && mv /tmp/config.json /opt/mattermost/config/config.json
        fi

        systemctl restart nginx
    fi

    echo "Installation completed successfully!"
}

function remove_and_clean_mattermost() {
    systemctl stop mattermost || true
    systemctl disable mattermost || true
    systemctl stop nginx || true
    systemctl disable nginx || true
    rm -f /etc/systemd/system/mattermost.service
    rm -f /etc/systemd/system/nginx.service

    if [ "$install_method" == "package" ]; then
        apt remove --purge -y mattermost
    else
        rm -rf /opt/mattermost
    fi

    # Remove Mattermost user and group
    userdel -r mattermost || true
    groupdel mattermost || true

    apt remove --purge -y postgresql* nginx*
    apt autoremove -y
    rm -rf /var/www /etc/nginx /etc/postgresql-common /var/lib/postgresql

    echo "Mattermost removed and cleaned successfully!"
}

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <install|remove> [package|archive]"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

ACTION=$1

case $ACTION in
    install)
        if [ "$#" -lt 2 ]; then
            echo "Please specify installation method: package or archive"
            exit 1
        fi
        install_method=$2
        install_mattermost
        ;;
    remove)
        remove_and_clean_mattermost
        ;;
    *)
        echo "Invalid action. Use install or remove."
        exit 1
        ;;
esac