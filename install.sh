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

# Install wget
install_wget() {
    check_install wget
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

# Run all setup functions
detect_os
update_system
install_docker
install_wget
setup_docker

echo "System setup complete."
                                             
# Function to prompt for input with default value
prompt_for_input() {
    local prompt="$1"
    local default_value="$2"
    read -p "$prompt [$default_value]: " input
    echo "${input:-$default_value}"
}

# Prompt for Global Settings
echo "Setting up the environment variables..."

# Ask user for license key and forwarder name
LICENSE_KEY=$(prompt_for_input "Enter your License Key (you can find it here: https://nxtfireguard.de/pages/dashboard/account)" "your_license_key")
FORWARDER_NAME=$(prompt_for_input "What would you like to name your Threat-Log-Forwarder?" "forwarder-name")

# Prompt to enable or disable RUN_LOGSTASH and RUN_SYSLOG
RUN_SYSLOG=$(prompt_for_input "Do you want to integrate with Cisco-FMC and/or Cisco-ISE (enable RUN_SYSLOG)? (true/false)" "false")
RUN_LOGSTASH=$(prompt_for_input "Do you want to integrate with T-Pot and enable Logstash? (enable RUN_LOGSTASH)? (true/false)" "false")

# Prepare .env file
ENV_FILE=".env"
echo "# Global Settings" > $ENV_FILE
echo "RUN_LOGSTASH=$RUN_LOGSTASH" >> $ENV_FILE
echo "RUN_SYSLOG=$RUN_SYSLOG" >> $ENV_FILE
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

# Start the services using run.sh
echo "Starting services with run.sh..."
./run.sh start

# Provide additional instructions based on the user's selections
echo -e "\nSetup completed.\n"

# Instructions for T-Pot (Logstash)
if [[ "$RUN_LOGSTASH" == "true" ]]; then
    echo -e "\nYou have enabled T-Pot (Logstash). Once the setup is complete, follow these steps to verify:"
    echo "- Ensure that T-Pot is properly sending logs to NxtFireGuard."
    echo "- Double-check that the Elasticsearch URL, User, and Password are correct."
    echo "- Verify that the hostname in NxtFireGuard matches your T-Pot instance (case sensitive)."
    echo -e "\nIf you encounter problems:"
    echo "- Ensure your T-Pots elasticsearch container is running and accessible."
    echo "- If the logs aren’t coming through, check the network connectivity between T-Pot and NxtFireGuard."
    echo "- For support or any issues, visit: https://nxtfireguard.de/pages/contact-form?topic=support"
    echo ""
fi

# Instructions for Syslog (Cisco-FMC and Cisco-ISE)
if [[ "$RUN_SYSLOG" == "true" ]]; then
    echo -e "\nYou have enabled Syslog integration for Cisco-FMC and/or Cisco-ISE. Once the setup is complete, follow these steps to verify:"
    echo "- Ensure that Syslog logs are being forwarded to NxtFireGuard."
    echo "- Double-check the license key and configuration in syslog-ng.conf."
    echo "- Verify that the hostname in NxtFireGuard matches your Cisco-FTD(s) or Cisco-ISE (case sensitive)."
    echo -e "\nIf you encounter problems:"
    echo "- Verify the Syslog configuration on your Cisco-FMC or Cisco-ISE to ensure logs are being sent correctly."
    echo "- For support or any issues, visit: https://nxtfireguard.de/pages/contact-form?topic=support"
    echo ""
    echo -e "\nHow to configure your Cisco ISE and Cisco FMC:"
    echo "- Point Cisco ISE authentication logs to the IP/hostname of this server on port UDP 1025."
    echo "  For detailed instructions, visit: https://docs.nxtfireguard.de/docs/Hosts/cisco-identity-services-engine"
    echo "- Point Cisco FMC to the IP/hostname of this server on port UDP 514."
    echo "  For detailed instructions, visit: https://docs.nxtfireguard.de/docs/Hosts/cisco-firewall-management-center"
    echo ""
fi

# Instructions
echo -e "\nInstructions for using run.sh:"
echo "./run.sh start   -> Start the service"
echo "./run.sh stop    -> Stop the service"
echo "./run.sh restart -> Restart the service"
echo -e "\nTo enable or disable Logstash or Syslog later on, simply modify the .env file or visit the respective documentation on docs.nxtfireguard.de, then run './run.sh restart'."
echo -e "\nTo update the Forwarder installation, run './update.sh'."

echo -e "\nSetup Complete! If you have any issues or need further assistance, don't hesitate to reach out to us at: https://nxtfireguard.de/pages/contact-form?topic=support"


