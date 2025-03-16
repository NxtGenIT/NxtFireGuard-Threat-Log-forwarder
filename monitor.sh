#!/bin/bash

# Load environment variables from .env file
set -o allexport
source "$(dirname "$0")/.env"
set +o allexport

LOGSTASH_SERVICE="nfg-logstash"
SYSLOG_SERVICE="nfg-syslog"
API_URL="https://api.nxtfireguard.de/threat-log-forwarder/inactive"

# Initialize an empty array to store services to monitor
SERVICES=()

# Check which services to monitor from .env
if [[ "$RUN_LOGSTASH" == "true" ]]; then
    SERVICES+=("$LOGSTASH_SERVICE")
fi

if [[ "$RUN_SYSLOG" == "true" ]]; then
    SERVICES+=("$SYSLOG_SERVICE")
fi

# If no services are enabled, exit
if [[ ${#SERVICES[@]} -eq 0 ]]; then
    echo "No services enabled to monitor. Exiting." 
    exit 0
fi

# Function to monitor services and check for crashes
monitor_services() {
    while true; do
        for service in "${SERVICES[@]}"; do
            # Check if the service is running
            container_status=$(docker ps -f "name=$service" --format "{{.Status}}")

            # Determine the forwarder type based on the service name
            local forwarder_type=""
            if [[ "$service" == "$LOGSTASH_SERVICE" ]]; then
                forwarder_type="nfg-logstash"
            elif [[ "$service" == "$SYSLOG_SERVICE" ]]; then
                forwarder_type="nfg-syslog"
            fi

            if [[ -z "$container_status" ]]; then
                # Container is not running, it might have crashed
                echo "$service has stopped. Checking logs..." >> nfg.log

                # Check if the container exists at all
                container_exists=$(docker ps -a -f "name=$service" --format "{{.ID}}")

                if [[ -z "$container_exists" ]]; then
                    # Container doesn't exist anymore
                    error_logs="Container for service $service not found. It may have been removed."
                else
                    # Container exists but is not running, get its logs
                    error_logs=$(docker logs --tail 20 "$service" 2>&1 || echo "Failed to retrieve logs for $service")
                fi

                # Call the API to report the crash with logs
                call_api "$FORWARDER_NAME" "$forwarder_type" "$X_LICENSE_KEY" "down" "$error_logs"
            else
                # Container is running fine, send heartbeat
                call_api "$FORWARDER_NAME" "$forwarder_type" "$X_LICENSE_KEY" "up"
            fi
        done

        # Clear log file if necessary
        clear_log_file

        # Wait for some time before rechecking the status
        sleep 10
    done
}

# Function to call the API with the error message
call_api() {
    local forwarder_name="$1"
    local forwarder_type="$2"
    local license="$3"
    local status="$4"
    local error_message="$5"

    # Build base payload
    payload=$(jq -n \
        --arg forwarder_name "$forwarder_name" \
        --arg forwarder_type "$forwarder_type" \
        --arg license "$license" \
        --arg status "$status" \
        '{
            "forwarder-name": $forwarder_name,
            "forwarder-type": $forwarder_type,
            "license": $license,
            "status": $status,
        }')

    # Include error-log only if status is "down"
    if [[ "$status" == "down" ]]; then
        payload=$(echo "$payload" | jq --arg error_message "$error_message" '. + { "error-log": $error_message }')
    fi

    # Send the error logs to the API
    api_response=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "X-License-Key: $license" \
        -d "$payload" 2>&1)

    # Get the current timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    # Log the message with timestamp and API response
    if [[ "$status" == "down" ]]; then
        echo "$timestamp - Error reported for $forwarder_name. API response: $api_response" >> nfg.log
    else
        echo "$timestamp - Heartbeat sent. API response: $api_response" >> nfg.log
    fi
}

# Function to check and clear log file if it exceeds the threshold
clear_log_file() {
    local log_file="nfg.log"
    local max_size_kb=10240  # 10MiB threshold
    
    # Check if file exists
    if [[ -f "$log_file" ]]; then
        # Get file size in KiB
        local file_size=$(du -k "$log_file" | cut -f1)
        
        # If file size exceeds threshold, clear it
        if [[ $file_size -gt $max_size_kb ]]; then
            timestamp=$(date "+%Y-%m-%d %H:%M:%S")
            
            # Clear the file but keep a backup
            echo "$timestamp - Log file cleared due to size limit ($max_size_kb KB)." > "$log_file"
        fi
    fi
}

# Function to start the monitoring in the background
start_services() {
    # Check if the monitoring process is already running
    if [[ -f "$(dirname "$0")/.monitor-pid" ]]; then
        echo "Monitoring service is already running."
        exit 0
    fi

    echo "Starting monitoring services..."

    # Run the monitoring function in the background
    monitor_services &
    MONITOR_PID=$!
    
    # Save the PID to a file
    echo "$MONITOR_PID" > "$(dirname "$0")/.monitor-pid"
    
    echo "Monitoring started."
}


# Function to stop the monitoring gracefully
stop_services() {
    if [[ ! -f "$(dirname "$0")/.monitor-pid" ]]; then
        echo "No monitoring process is currently running."
        exit 0
    fi

    MONITOR_PID=$(cat "$(dirname "$0")/.monitor-pid")
    
    if [[ -z "$MONITOR_PID" ]]; then
        echo "No monitoring process is currently running."
        exit 0
    fi

    # Kill the monitoring process by its PID
    kill "$MONITOR_PID"

    # delete PID file
    rm "$(dirname "$0")/.monitor-pid"

    echo "Monitoring stopped."
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
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac