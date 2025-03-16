#!/bin/bash

# Load environment variables from .env file
set -o allexport
source "$(dirname "$0")/.env"
set +o allexport

# Check and update configuration before proceeding
check_and_update_config

# Service names from docker-compose
LOGSTASH_SERVICE="nfg-logstash"
SYSLOG_SERVICE="nfg-syslog"

# All defined services (whether enabled or not)
ALL_SERVICES=("$LOGSTASH_SERVICE" "$SYSLOG_SERVICE")

# Services to start based on .env file
SERVICES_TO_START=()
[[ "$RUN_LOGSTASH" == "true" ]] && SERVICES_TO_START+=("$LOGSTASH_SERVICE")
[[ "$RUN_SYSLOG" == "true" ]] && SERVICES_TO_START+=("$SYSLOG_SERVICE")

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

    # Update RUN_LOGSTASH and RUN_SYSLOG in the .env file
    if [[ -f .env ]]; then
        sed -i "s/^RUN_LOGSTASH=.*/RUN_LOGSTASH=$logstash_enabled/" .env
        sed -i "s/^RUN_SYSLOG=.*/RUN_SYSLOG=$syslog_enabled/" .env
    else
        echo "RUN_LOGSTASH=$logstash_enabled" > .env
        echo "RUN_SYSLOG=$syslog_enabled" >> .env
    fi

    # Log success message
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Configuration fetched successfully and updated." >> nfg.log
    # Change ownership of .env and nfg.log to the actual user if run with sudo
    REAL_USER=${SUDO_USER:-$USER}
    chown "$REAL_USER:$REAL_USER" .env nfg.log

    return 0
}

# Function to call the API with the error message
call_api_stop_service() {
    local license="$1"
    local forwarder_name="$2"
    local api_url="https://api.nxtfireguard.de/threat-log-forwarder/stop?Forwarder-Name=${forwarder_name}"

    # Send the stop request to the API
    api_response=$(curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -H "X-License-Key: $license" \
        2>&1)

    # Get the current timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    # Log the message with timestamp and API response
    echo "$timestamp - Service stopped reported for $forwarder_name. API response: $api_response" >> nfg.log
}



# Check and update configuration
check_and_update_config() {
    if [ -z "$X_LICENSE_KEY" ] || [ -z "$FORWARDER_NAME" ]; then
        echo "Error: X_LICENSE_KEY or FORWARDER_NAME not set in .env file."
        exit 1
    fi

    fetch_config "$X_LICENSE_KEY" "$FORWARDER_NAME"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch configuration. Using existing configuration."
    else
        echo "Configuration updated successfully."
    fi
}

# Function to check service status
status_services() {
    echo "Checking configured service status..."
    
    if [[ ${#SERVICES_TO_START[@]} -eq 0 ]]; then
        echo "No services are enabled in the .env file."
    else
        for SERVICE in "${SERVICES_TO_START[@]}"; do
            CONTAINER_ID=$(docker ps -aq -f name="^${SERVICE}$")

            if [[ -n "$CONTAINER_ID" ]]; then
                RUNNING=$(docker ps -q -f id="$CONTAINER_ID")
                if [[ -n "$RUNNING" ]]; then
                    echo "$SERVICE is running."
                else
                    echo "$SERVICE exists but is stopped."
                fi
            else
                echo "$SERVICE is not found."
            fi
        done
    fi

    check_monitoring_script
}

# Function to check if the monitoring script is running
check_monitoring_script() {
    MONITOR_PID=$(pgrep -f "./monitor.sh start")

    if [[ -n "$MONITOR_PID" ]]; then
        echo "Monitoring script is running (PID: $MONITOR_PID)."
    else
        echo "Monitoring script is not running."
    fi
}

# Function to start services
start_services() {
    # Check and update configuration before proceeding
    check_and_update_config

    # Reload environment variables after potential update
    set -o allexport
    source "$(dirname "$0")/.env"
    set +o allexport

    
    # Recalculate services to start based on updated .env file
    SERVICES_TO_START=()
    [[ "$RUN_LOGSTASH" == "true" ]] && SERVICES_TO_START+=("$LOGSTASH_SERVICE")
    [[ "$RUN_SYSLOG" == "true" ]] && SERVICES_TO_START+=("$SYSLOG_SERVICE")


    if [[ ${#SERVICES_TO_START[@]} -eq 0 ]]; then
        echo "No services enabled to run. Exiting."
        exit 0
    fi

    echo "Checking service status..."

    SERVICES_TO_LAUNCH=()

    for SERVICE in "${SERVICES_TO_START[@]}"; do
        CONTAINER_ID=$(docker ps -aq -f name="^${SERVICE}$")

        if [[ -n "$CONTAINER_ID" ]]; then
            RUNNING=$(docker ps -q -f id="$CONTAINER_ID")

            if [[ -n "$RUNNING" ]]; then
                echo "$SERVICE is already running."
            else
                echo "Found stopped container for $SERVICE. Removing it..."
                docker rm "$CONTAINER_ID"
                SERVICES_TO_LAUNCH+=("$SERVICE")
            fi
        else
            echo "Starting $SERVICE..."
            SERVICES_TO_LAUNCH+=("$SERVICE")
        fi
    done

    if [[ ${#SERVICES_TO_LAUNCH[@]} -gt 0 ]]; then
        docker compose up -d "${SERVICES_TO_LAUNCH[@]}"
    else
        echo "All services are already running. No action needed."
    fi

    # Start the monitoring script after services are started
    ./monitor.sh start
}


# Function to stop running services (even if disabled in .env)
stop_services() {
    # First stop the monitoring script
    ./monitor.sh stop
    
    RUNNING_SERVICES=()

    # Check which services are running
    for SERVICE in "${ALL_SERVICES[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^$SERVICE\$"; then
            RUNNING_SERVICES+=("$SERVICE")
        fi
    done

    if [[ ${#RUNNING_SERVICES[@]} -eq 0 ]]; then
        echo "No running services found. Exiting."
        exit 0
    fi

    echo "Stopping running services: ${RUNNING_SERVICES[*]}"
    docker compose stop "${RUNNING_SERVICES[@]}"
    call_api_stop_service "$X_LICENSE_KEY" "$FORWARDER_NAME"
}

# Command-line handling
case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        start_services
        ;;
    status)
        status_services
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
