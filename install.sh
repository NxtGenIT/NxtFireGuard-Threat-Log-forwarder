#!/bin/bash

# Function to check for installed packages
check_install() {
    if ! dpkg -l | grep -q "^ii  $1 "; then
        echo "Installing $1..."
        sudo apt-get install -y "$1"
    else
        echo "$1 is already installed."
    fi
}

# Detect Linux distribution
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        echo "Unsupported Linux distribution. Exiting."
        exit 1
    fi
}

# Update system packages
update_system() {
    echo "Updating system packages..."
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt-get update -y && sudo apt-get upgrade -y
    else
        echo "Skipping system update: Unsupported distribution ($OS)."
    fi
}

# Install Docker on Ubuntu/Debian
install_docker() {
    if command -v docker &> /dev/null; then
        echo "Docker is already installed."
        return
    fi

    echo "Installing Docker..."
    
    # Remove conflicting packages
    echo "Removing conflicting packages..."
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
        sudo apt-get remove -y $pkg 
    done

    # Add Docker repository
    echo "Adding Docker repository..."
    check_install ca-certificates
    check_install curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/$OS/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo "Adding Docker APT source..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$OS \
    $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    check_install docker-ce
    check_install docker-ce-cli
    check_install containerd.io
    check_install docker-buildx-plugin
    check_install docker-compose-plugin

    echo "Docker installation complete!"
}

setup_docker() {
    if systemctl is-active --quiet docker; then
        echo "Docker is already running and enabled."
    else
        echo "Setting up Docker..."
        sudo systemctl start docker
        sudo systemctl enable docker
        echo "Docker setup complete!"
    fi
}

# Function to add user to the Docker group and reload shell
docker_permissions() {
    # Check if the docker group exists, create it if not
    if ! getent group docker > /dev/null; then
        echo "Creating the 'docker' group..."
        groupadd docker
        echo "'docker' group created."
    fi

    # Check if the user is already in the docker group
    if ! groups "$REAL_USER" | grep -q "\bdocker\b"; then
        echo "Adding user $REAL_USER to the Docker group..."
        usermod -aG docker "$REAL_USER"
        echo "User $REAL_USER added to the Docker group."
    else
        echo "User $REAL_USER is already in the Docker group."
    fi
}

# Function to create the systemd service
create_systemd_service() {
    SCRIPT_PATH="$(dirname "$(realpath "$0")")"
    SERVICE_FILE="/etc/systemd/system/nfg-threat-forwarder.service"

    # Check if the service file already exists
    if [ -f "$SERVICE_FILE" ]; then
        echo "Systemd service already exists at $SERVICE_FILE."
        read -p "Do you want to overwrite it? (y/n): " choice
        case "$choice" in
        y|Y)
            echo "Overwriting the service..."
            ;;
        *)
            echo "Aborting..."
            exit 0
            ;;
        esac
    fi

    # Create the systemd service file
    echo "Creating systemd service at $SERVICE_FILE..."

    sudo touch $SERVICE_FILE

    # Write the service configuration
    sudo echo "[Unit]" > $SERVICE_FILE
    sudo echo "Description=NxtFireGuard Threat-Log-Forwarder" >> $SERVICE_FILE
    sudo echo "After=network.target" >> $SERVICE_FILE
    sudo echo "" >> $SERVICE_FILE
    sudo echo "[Service]" >> $SERVICE_FILE
    sudo echo "Type=forking" >> $SERVICE_FILE
    sudo echo "ExecStart=/bin/bash $SCRIPT_PATH/run.sh start" >> $SERVICE_FILE
    sudo echo "ExecStop=/bin/bash $SCRIPT_PATH/run.sh stop" >> $SERVICE_FILE
    sudo echo "ExecReload=/bin/bash $SCRIPT_PATH/run.sh restart" >> $SERVICE_FILE
    sudo echo "WorkingDirectory=$SCRIPT_PATH" >> $SERVICE_FILE
    sudo echo "Restart=on-failure" >> $SERVICE_FILE
    sudo echo "User=$REAL_USER" >> $SERVICE_FILE
    sudo echo "Group=$REAL_USER" >> $SERVICE_FILE
    sudo echo "" >> $SERVICE_FILE
    sudo echo "[Install]" >> $SERVICE_FILE
    sudo echo "WantedBy=multi-user.target" >> $SERVICE_FILE

    echo "Systemd service created successfully at $SERVICE_FILE."

    # Reload systemd to register the new service
    sudo systemctl daemon-reload

    # Enable the service
    sudo systemctl enable nfg-threat-forwarder.service

    echo "Service is now enabled."
}

# Function to prompt for input with default value
prompt_for_input() {
    local prompt_message="$1"
    local default_value="$2"
    read -p "$prompt_message [$default_value]: " input
    echo "${input:-$default_value}"
}

# Function to prompt for yes/no and convert to true/false
prompt_for_boolean() {
    local prompt_message="$1"
    local default_value="$2"  # Expected default is "false" or "true"

    while true; do
        read -p "$prompt_message (y/n) [$default_value]: " input
        input="${input,,}"  # Convert to lowercase

        case "$input" in
            y|yes) echo "true"; break ;;
            n|no) echo "false"; break ;;
            "") echo "$default_value"; break ;;  # Use default if empty
            *) echo "Invalid input. Please enter y or n." ;;
        esac
    done
}

# Function to get config from API
fetch_config() {
    local license="$1"
    local forwarder_name="$2"
    local api_url="https://api.nxtfireguard.de/threat-log-forwarder/config"

    # Fetch the configuration from the API
    response=$(curl -s -X GET "$api_url?Forwarder-Name=$forwarder_name" \
        -H "X-License-Key: $license" \
        -H "Accept: application/json")

    # Check if the API call was successful
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to fetch configuration from the API."
        return 1
    fi

    # Parse the response to extract logstash_enabled and syslog_enabled
    logstash_enabled=$(echo "$response" | jq -r '.logstash_enabled')
    syslog_enabled=$(echo "$response" | jq -r '.syslog_enabled')

    # Validate the response fields
    if [[ "$logstash_enabled" == "null" || "$syslog_enabled" == "null" ]]; then
        echo "Error: Invalid response from the API. Please check your license key and forwarder name."
        return 1
    fi

    # Write the values to a .env file
    echo "RUN_LOGSTASH=$logstash_enabled" > .env
    echo "RUN_SYSLOG=$syslog_enabled" >> .env

    # Log success message
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Configuration fetched successfully and written to .env file." >> nfg.log

    return 0
}

echo -e "\n  _   _      _   _____ _           ____                     _ "
echo " | \\ | |_  _| |_|  ___(_)_ __ ___ / ___|_   _  __ _ _ __ __| |"
echo " |  \\| \\ \\/ / __| |_  | | '__/ _ \\ |  _| | | |/ _\` | '__/ _\` |"
echo " | |\\  |>  <| |_|  _| | | | |  __/ |_| | |_| | (_| | | | (_| |"
echo " |_| \\_/_/\\_\\\\__|_|   |_|_|  \\___|\\____|\\__,_|\\__,_|_|  \\__,_|"
echo -e "\nWelcome to NxtFireGuard Threat-Log-Forwarder Setup!\n"

# Check if script is run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run with: sudo $0"
    exit 1
fi

# get Username
REAL_USER=${SUDO_USER:-$USER}

# Run all setup functions
detect_os
update_system
check_install jq
install_docker
setup_docker
docker_permissions

echo "System setup complete."

# Prompt for Global Settings
echo "Setting up the environment variables..."

# Ask user for license key and forwarder name
LICENSE_KEY=$(prompt_for_input "Enter your License Key (you can find it here: https://nxtfireguard.de/pages/dashboard/account)" "your_license_key")
FORWARDER_NAME=$(prompt_for_input "What would you like to name your Threat-Log-Forwarder?" "forwarder-name")

# Prepare .env file
ENV_FILE=".env"
echo "# Global Settings" > $ENV_FILE

# Fetch config (enable disable logstash and syslog) from API
fetch_config "$LICENSE_KEY" "$FORWARDER_NAME"

# Load newly written env variables
source $ENV_FILE

echo "X_LICENSE_KEY=$LICENSE_KEY" >> $ENV_FILE
echo "FORWARDER_NAME=$FORWARDER_NAME" >> $ENV_FILE
echo "" >> $ENV_FILE

# Prompt for T-Pot specific settings if RUN_LOGSTASH is enabled
if [[ "$RUN_LOGSTASH" == "true" ]]; then
    echo "You have enabled T-Pot (Logstash). Let's configure the Elasticsearch settings."
    ELK_URL=$(prompt_for_input "Enter the URL for your Elasticsearch instance (default: http://elasticsearch:9200)" "http://elasticsearch:9200")
    ELK_USER=$(prompt_for_input "Enter the Elasticsearch User (default: elastic)" "elastic")
    ELK_PASSWORD=$(prompt_for_input "Enter the Elasticsearch Password (default: changeme)" "changeme")
    
    # Add T-Pot specific settings to the .env file
    echo "# T-Pot specific settings" >> $ENV_FILE
    echo "ELK_URL=$ELK_URL" >> $ENV_FILE
    echo "ELK_USER=$ELK_USER" >> $ENV_FILE
    echo "ELK_PASSWORD=$ELK_PASSWORD" >> $ENV_FILE
fi

# Add T-Pot specific settings to the .env file (default values) as RUN_LOGSTASH is false
echo "# T-Pot specific settings" >> $ENV_FILE
echo "ELK_URL=http://elasticsearch:9200" >> $ENV_FILE
echo "ELK_USER=elastic" >> $ENV_FILE
echo "ELK_PASSWORD=changeme" >> $ENV_FILE

# Update syslog-ng.conf if RUN_SYSLOG is enabled
if [[ "$RUN_SYSLOG" == "true" ]]; then
    echo "Updating syslog-ng.conf with your license key..."
    sed -i "s/<your-license-key>/$LICENSE_KEY/g" syslog/syslog-ng.conf
fi

# Make run.sh and monitor.sh executable
chmod +x run.sh
chmod +x monitor.sh

# Create systemd service
create_systemd_service

# Change ownership of .env and nfg.log to the actual user
chown "$REAL_USER:$REAL_USER" .env nfg.log

# Provide additional instructions based on the user's selections
echo -e "\nSetup completed.\n"

if [[ "$RUN_LOGSTASH" == "true" ]]; then
    echo "You have enabled T-Pot (Logstash). Visit the following Page to complete the setup:"
    echo "https://docs.nxtfireguard.de/docs/Hosts/honeypot-tpot#next-steps"
    echo ""
fi

if [[ "$RUN_SYSLOG" == "true" ]]; then
    echo "You have enabled Syslog integration. Visit the following Page(s) to complete the setup:"
    echo "- Cisco ISE: https://docs.nxtfireguard.de/docs/Hosts/cisco-identity-services-engine#next-steps"
    echo "- Cisco FMC: https://docs.nxtfireguard.de/docs/Hosts/cisco-firewall-management-center#next-steps"
    echo ""
fi

# Final Instructions
echo -e "\nNext Steps:"
echo "1. Log out and log back in to apply Docker group changes (or run 'newgrp docker')."
echo "2. Start the services by running: sudo systemctl start nfg-threat-forwarder"
echo "3. Check on the service by running: sudo systemctl status nfg-threat-forwarder"
echo -e "\nFor help, visit: https://nxtfireguard.de/pages/contact-form?topic=support"