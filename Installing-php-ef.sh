#!/bin/bash

# Detect OS
if [ -f /etc/oracle-release ]; then
    OS="oracle"
elif [ -f /etc/redhat-release ]; then
    OS="rhel"
elif [ -f /etc/debian_version ]; then
    OS="debian"
else
    echo "Unsupported OS. Only Oracle Linux, RHEL-based, and Debian-based distributions are supported."
    exit 1
fi

# Generate random HWID and Security Salt
HWID=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24)
SECURITY_SALT=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 30)

# Install Docker and Docker Compose
if [ "$OS" = "oracle" ] || [ "$OS" = "rhel" ]; then
    echo "Installing Docker and Docker Compose for Oracle/RHEL-based OS..."
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io
elif [ "$OS" = "debian" ]; then
    echo "Installing Docker and Docker Compose for Debian-based OS..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
fi

# Start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Install Docker Compose Plugin
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify Docker Compose
docker compose version || { echo "Docker Compose installation failed."; exit 1; }

# Create directories
echo "Setting up directories for PHP-ef..."
sudo mkdir -p /docker/php-ef/config /docker/php-ef/plugins
sudo chown -R nobody:nobody /docker/php-ef

# Download config.json.example and update salt
CONFIG_URL="https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/inc/config/config.json.example"
sudo curl -L "$CONFIG_URL" -o /docker/php-ef/config/config.json
sudo sed -i "s/somesupersecurepasswordhere/$SECURITY_SALT/" /docker/php-ef/config/config.json

# Create docker-compose.yml
cat <<EOF | sudo tee /docker/docker-compose.yml
version: '3'
services:
  php-ef:
    image: ghcr.io/tehmuffinmoo/php-ef:dev
    ports:
      - 80:8080
    environment:
      HWID: $HWID
      LOGLEVEL: INFO
    restart: always
    volumes:
      - ./php-ef/config:/var/www/html/inc/config
      - ./php-ef/plugins:/var/www/html/inc/plugins
EOF

# Start PHP-ef container
echo "Starting PHP-ef container..."
sudo docker compose -f /docker/docker-compose.yml up -d

# Add cron job to update and restart the service daily
echo "Creating cron job for daily updates..."
(crontab -l 2>/dev/null; echo "0 0 * * * docker compose -f /docker/docker-compose.yml pull && docker compose -f /docker/docker-compose.yml down && docker compose -f /docker/docker-compose.yml up -d") | crontab -

echo "Installation complete!"
