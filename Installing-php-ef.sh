#!/bin/bash

# Check if this script is being sourced
([[ -n $ZSH_EVAL_CONTEXT && $ZSH_EVAL_CONTEXT =~ :file$ ]] || 
 [[ -n $BASH_VERSION && $0 != "$BASH_SOURCE" ]]) && sourced=1 || sourced=0

if [ $sourced -eq 1 ]; then
    echo "This script should not be sourced"
    return 1
fi

# Function to download and run installer
download_and_run() {
    local TEMP_DIR=$(mktemp -d)
    local SCRIPT_PATH="$TEMP_DIR/installer.sh"
    
    # Download the script
    if ! curl -fsSL https://raw.githubusercontent.com/tinytechlabuk/php-ef-installers/main/Installing-php-ef.sh -o "$SCRIPT_PATH"; then
        echo "Failed to download installer script"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Make it executable
    chmod +x "$SCRIPT_PATH"
    
    # Run the script
    bash "$SCRIPT_PATH"
    
    # Clean up
    rm -rf "$TEMP_DIR"
}

# If script is downloaded via curl, run the download_and_run function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ -p /dev/stdin ]]; then
    download_and_run
    exit $?
fi

# Ensure script can handle being piped
exec < /dev/tty

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
        sudo yum install -y yum-utils device-mapper-persistent-data lvm2 > /dev/null 2>&1
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null 2>&1
        sudo yum install -y docker-ce docker-ce-cli containerd.io > /dev/null 2>&1
    elif [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common > /dev/null 2>&1
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg > /dev/null 2>&1
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 2>&1
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io > /dev/null 2>&1
    fi

    echo "Starting Docker service..."
    sudo systemctl enable docker > /dev/null 2>&1
    sudo systemctl start docker > /dev/null 2>&1

    echo "Installing Docker Compose..."
    # Install Docker Compose Plugin
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)" -o /usr/local/bin/docker-compose > /dev/null 2>&1
    sudo chmod +x /usr/local/bin/docker-compose > /dev/null 2>&1
}

# Function to setup Docker configuration
setup_docker_config() {
    local HWID=$1
    local SECURITY_SALT=$2
    local DOCKER_PATH=${3:-/docker}  # Use third parameter or default to /docker
    
    echo "Setting up Docker configuration..."
    sudo mkdir -p "$DOCKER_PATH/php-ef/config" "$DOCKER_PATH/php-ef/plugins" > /dev/null 2>&1

    echo "Downloading configuration files..."
    # Download and configure config.json
    CONFIG_URL="https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/inc/config/config.json.example"
    sudo curl -L "$CONFIG_URL" -o "$DOCKER_PATH/php-ef/config/config.json" > /dev/null 2>&1
    sudo sed -i "s/somesupersecurepasswordhere/$SECURITY_SALT/" "$DOCKER_PATH/php-ef/config/config.json" > /dev/null 2>&1

    echo "Creating Docker Compose configuration..."
    # Create docker-compose.yml
    cat <<EOF | sudo tee "$DOCKER_PATH/docker-compose.yml" > /dev/null 2>&1
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
    echo "Starting local PHP-EF installation..."
    
    # Install dependencies based on OS
    if [ "$OS" = "oracle" ] || [ "$OS" = "rhel" ]; then
        echo "Installing RHEL-based dependencies..."
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
            supervisor > /dev/null 2>&1

        echo "Configuring NGINX for RHEL..."
        # Configure NGINX for RHEL
        sudo mkdir -p /etc/nginx/conf.d > /dev/null 2>&1
        sudo curl -L "https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/Docker/config/nginx.conf" -o /etc/nginx/nginx.conf > /dev/null 2>&1
        sudo curl -L "https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/Docker/config/conf.d/default.conf" -o /etc/nginx/conf.d/default.conf > /dev/null 2>&1

    elif [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
        echo "Installing Debian/Ubuntu dependencies..."
        
        # For Ubuntu, we need to add PHP repository
        if [ "$OS" = "ubuntu" ]; then
            echo "Adding PHP repository for Ubuntu..."
            sudo apt-get update > /dev/null 2>&1
            sudo apt-get install -y software-properties-common > /dev/null 2>&1
            sudo add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
        fi
        
        sudo apt-get update > /dev/null 2>&1
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
            supervisor > /dev/null 2>&1

        echo "Configuring NGINX for Debian/Ubuntu..."
        # Configure NGINX for Debian/Ubuntu
        sudo mkdir -p /etc/nginx/conf.d > /dev/null 2>&1
        sudo curl -L "https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/Docker/config/nginx.conf" -o /etc/nginx/nginx.conf > /dev/null 2>&1
        sudo curl -L "https://raw.githubusercontent.com/TehMuffinMoo/php-ef/main/Docker/config/conf.d/default.conf" -o /etc/nginx/conf.d/default.conf > /dev/null 2>&1
    fi

    echo "Setting up PHP-EF application..."
    # Clone PHP-EF repository
    sudo git clone https://github.com/TehMuffinMoo/php-ef.git /var/www/html > /dev/null 2>&1
    
    echo "Configuring permissions..."
    # Set correct permissions
    sudo chown -R www-data:www-data /var/www/html > /dev/null 2>&1
    sudo chmod -R 755 /var/www/html > /dev/null 2>&1

    echo "Starting services..."
    # Start and enable services
    sudo systemctl enable nginx > /dev/null 2>&1
    sudo systemctl start nginx > /dev/null 2>&1
    sudo systemctl enable php8.3-fpm > /dev/null 2>&1
    sudo systemctl start php8.3-fpm > /dev/null 2>&1
    sudo systemctl enable redis > /dev/null 2>&1
    sudo systemctl start redis > /dev/null 2>&1

    # Generate HWID for local installation
    local HWID=$(generate_random 24)
    
    echo "Configuring PHP-EF..."
    # Configure PHP-EF
    sudo cp /var/www/html/inc/config/config.json.example /var/www/html/inc/config/config.json > /dev/null 2>&1
    sudo sed -i "s/somesupersecurepasswordhere/$(generate_random 30)/" /var/www/html/inc/config/config.json > /dev/null 2>&1

    echo "Local installation complete!"
    echo "Access the web interface at http://localhost"
    echo "Username: admin"
    echo "Password: Admin123!"
    echo "HWID: $HWID"
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
    local OS=$(detect_os)
    local INSTALL_TYPE=""
    local DOCKER_PATH="/docker"  # Default docker path

    # Check if OS is supported
    if [ "$OS" = "unsupported" ]; then
        echo "Unsupported operating system"
        exit 1
    fi

    # Ask for installation type
    while [ -z "$INSTALL_TYPE" ]; do
        echo "Please select installation type:"
        echo "1) Docker (Recommended)"
        echo "2) Local Installation"
        read -p "Enter your choice (1 or 2): " choice
        
        case $choice in
            1) INSTALL_TYPE="docker";;
            2) INSTALL_TYPE="local";;
            *) echo "Invalid choice. Please enter 1 or 2.";;
        esac
    done

    if [ "$INSTALL_TYPE" = "docker" ]; then
        # Ask for custom docker path
        read -p "Enter custom Docker installation path (press Enter for default '/docker'): " custom_path
        if [ ! -z "$custom_path" ]; then
            DOCKER_PATH="$custom_path"
        fi

        # Generate random strings for HWID and Security Salt
        local HWID=$(generate_random 24)
        local SECURITY_SALT=$(generate_random 30)
        
        install_docker "$OS"
        setup_docker_config "$HWID" "$SECURITY_SALT" "$DOCKER_PATH"
        
        # Start the container
        echo "Starting PHP-ef container..."
        cd "$DOCKER_PATH" && sudo docker compose up -d > /dev/null 2>&1
        
        # Set ownership before starting the container
        echo "Setting up permissions..."
        sudo chown -R nobody:nobody "$DOCKER_PATH/php-ef" > /dev/null 2>&1

        # Add daily update cron job
        echo "Creating update schedule..."
        (crontab -l 2>/dev/null; echo "0 0 * * * cd $DOCKER_PATH && docker compose pull && docker compose down && docker compose up -d") | sort - | uniq - | crontab - > /dev/null 2>&1
        
        echo "Installation completed successfully!"
        echo "Access the web interface at http://localhost"
        echo "Username: admin"
        echo "Password: Admin123!"
        echo "HWID: $HWID"
        
    elif [ "$INSTALL_TYPE" = "local" ]; then
        install_local "$OS"
    fi
}

# Run the main installation
main

# Self-delete the script if it exists
[ -f "$0" ] && rm -- "$0"
