#!/bin/bash

# Function to detect OS
detect_os() {
    if [ -f /etc/oracle-release ]; then
        echo "oracle"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        if [ -f /etc/lsb-release ] && grep -q "Ubuntu" /etc/lsb-release; then
            echo "ubuntu"
        else
            echo "debian"
        fi
    else
        echo "unsupported"
    fi
}

# Function to generate random strings
generate_random() {
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c $1
}

# Function to install Docker and Docker Compose
install_docker() {
    local OS=$1
    echo "Installing Docker and Docker Compose..."
    
    if [ "$OS" = "oracle" ] || [ "$OS" = "rhel" ]; then
        sudo yum install -y yum-utils device-mapper-persistent-data lvm2
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io
    elif [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    fi

    sudo systemctl enable docker
    sudo systemctl start docker

    # Install Docker Compose Plugin
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
}

# Function to setup Docker configuration
setup_docker_config() {
    local HWID=$1
    local SECURITY_SALT=$2
    
    echo "Setting up Docker configuration..."
    sudo mkdir -p /docker/php-ef/config /docker/php-ef/plugins
    sudo chown -R nobody:nobody /docker/php-ef

    # Download and configure config.json
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
}

# Function to install PHP-EF locally (automated installation from Dockerfile)
install_local() {
    local OS=$1
    echo "Installing PHP-EF locally..."
    
    # Install dependencies based on OS
    if [ "$OS" = "oracle" ] || [ "$OS" = "rhel" ]; then
        echo "Installing dependencies for RHEL-based system..."
        sudo yum install -y \
            curl \
            php \
            php-ldap \
            php-ctype \
            php-sqlite3 \
            php-pdo \
            php-pdo_sqlite \
            php-curl \
            php-dom \
            php-fileinfo \
            php-fpm \
            php-gd \
            php-intl \
            php-mbstring \
            php-mysqli \
            php-opcache \
            php-openssl \
            php-phar \
            php-session \
            php-tokenizer \
            php-xml \
            php-xmlreader \
            php-xmlwriter \
            php-simplexml \
            nginx \
            redis \
            git \
            supervisor

        # Configure NGINX for RHEL
        sudo mkdir -p /etc/nginx/conf.d
        sudo curl -L "https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/Docker/config/nginx.conf" -o /etc/nginx/nginx.conf
        sudo curl -L "https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/Docker/config/conf.d/default.conf" -o /etc/nginx/conf.d/default.conf

    elif [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
        echo "Installing dependencies for Debian/Ubuntu system..."
        
        # For Ubuntu, we need to add PHP repository
        if [ "$OS" = "ubuntu" ]; then
            sudo apt-get update
            sudo apt-get install -y software-properties-common
            sudo add-apt-repository -y ppa:ondrej/php
        fi
        
        sudo apt-get update
        sudo apt-get install -y \
            curl \
            composer \
            php8.3 \
            php8.3-ldap \
            php8.3-common \
            php8.3-sqlite3 \
            php8.3-mysql \
            php8.3-curl \
            php8.3-dom \
            php8.3-fileinfo \
            php8.3-fpm \
            php8.3-gd \
            php8.3-intl \
            php8.3-mbstring \
            php8.3-opcache \
            php8.3-xml \
            php8.3-zip \
            nginx \
            redis-server \
            git \
            supervisor

        # Configure NGINX for Debian/Ubuntu
        sudo mkdir -p /etc/nginx/conf.d
        sudo curl -L "https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/Docker/config/nginx.conf" -o /etc/nginx/nginx.conf
        sudo curl -L "https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/Docker/config/conf.d/default.conf" -o /etc/nginx/conf.d/default.conf
    fi

    # Create and setup web root
    echo "Setting up web root..."
    sudo mkdir -p /var/www/html
    cd /var/www/html

    # Clone PHP-EF repository
    echo "Cloning PHP-EF repository..."
    sudo git clone https://github.com/TehMuffinMoo/php-ef.git .

    # Configure PHP-FPM
    echo "Configuring PHP-FPM..."
    if [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
        PHP_VERSION="8.3"
        PHP_INI_DIR="/etc/php/$PHP_VERSION"
    else
        PHP_VERSION="php"
        PHP_INI_DIR="/etc/php"
    fi
    
    sudo mkdir -p ${PHP_INI_DIR}/php-fpm.d
    sudo curl -L "https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/Docker/config/fpm-pool.conf" -o ${PHP_INI_DIR}/php-fpm.d/www.conf
    sudo curl -L "https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/Docker/config/php.ini" -o ${PHP_INI_DIR}/conf.d/custom.ini

    # Configure Supervisord
    echo "Configuring Supervisord..."
    sudo mkdir -p /etc/supervisor/conf.d
    sudo curl -L "https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/Docker/config/supervisord.conf" -o /etc/supervisor/conf.d/supervisord.conf

    # Configure Redis
    echo "Configuring Redis..."
    sudo mkdir -p /etc/redis
    sudo curl -L "https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/Docker/config/redis.conf" -o /etc/redis/redis.conf

    # Set permissions
    echo "Setting permissions..."
    sudo chown -R www-data:www-data /var/www/html
    sudo chown -R www-data:www-data /run /var/lib/nginx /var/log/nginx /var/log/redis

    # Configure Cron
    echo "Setting up cron job..."
    (sudo crontab -l 2>/dev/null; echo "* * * * * /usr/bin/php /var/www/html/inc/scheduler/scheduler.php") | sudo crontab -

    # Run composer update
    echo "Running composer update..."
    cd /var/www/html
    sudo -u www-data composer update

    # Start services
    echo "Starting services..."
    sudo systemctl enable nginx php$PHP_VERSION-fpm redis-server supervisor
    sudo systemctl start nginx php$PHP_VERSION-fpm redis-server supervisor

    echo "Local installation complete!"
    echo "You can access PHP-EF at http://localhost"
}

# Function to migrate existing installation to Docker
migrate_to_docker() {
    local INSTALL_PATH=$1
    echo "Migrating existing installation to Docker..."
    
    # Create Docker directories
    sudo mkdir -p /docker/php-ef/config /docker/php-ef/plugins
    
    # Copy existing configuration and plugins
    if [ -d "$INSTALL_PATH/inc/config" ]; then
        sudo cp -r "$INSTALL_PATH/inc/config"/* /docker/php-ef/config/
    fi
    
    if [ -d "$INSTALL_PATH/inc/plugins" ]; then
        sudo cp -r "$INSTALL_PATH/inc/plugins"/* /docker/php-ef/plugins/
    fi
    
    # Setup Docker configuration
    HWID=$(generate_random 24)
    setup_docker_config "$HWID" "$(generate_random 30)"
}

# Main installation script
main() {
    OS=$(detect_os)
    if [ "$OS" = "unsupported" ]; then
        echo "Unsupported OS. Only Oracle Linux, RHEL-based, Debian-based, and Ubuntu-based distributions are supported."
        exit 1
    fi

    echo "Welcome to PHP-EF Installer"
    echo "Please select installation type:"
    echo "1) Docker Installation (Recommended)"
    echo "2) Local Installation (Automated)"
    # echo "3) Migrate Existing Installation to Docker"
    read -p "Enter your choice (1-2): " CHOICE

    case $CHOICE in
        1)
            echo "Starting Docker installation..."
            install_docker "$OS"
            HWID=$(generate_random 24)
            SECURITY_SALT=$(generate_random 30)
            setup_docker_config "$HWID" "$SECURITY_SALT"
            echo "Starting PHP-ef container..."
            sudo docker compose -f /docker/docker-compose.yml up -d
            ;;
        2)
            echo "Starting automated local installation..."
            install_local "$OS"
            ;;
        3)
            read -p "Enter the path to your existing PHP-EF installation: " EXISTING_PATH
            if [ ! -d "$EXISTING_PATH" ]; then
                echo "Directory does not exist!"
                exit 1
            fi
            install_docker "$OS"
            migrate_to_docker "$EXISTING_PATH"
            echo "Starting migrated PHP-ef container..."
            sudo docker compose -f /docker/docker-compose.yml up -d
            ;;
        *)
            echo "Invalid choice!"
            exit 1
            ;;
    esac

    # Add cron job for Docker installations
    if [ "$CHOICE" = "1" ] || [ "$CHOICE" = "3" ]; then
        echo "Creating cron job for daily updates..."
        (crontab -l 2>/dev/null; echo "0 0 * * * docker compose -f /docker/docker-compose.yml pull && docker compose -f /docker/docker-compose.yml down && docker compose -f /docker/docker-compose.yml up -d") | crontab -
    fi

    echo "Installation complete!"
}

# Run the main installation
main
