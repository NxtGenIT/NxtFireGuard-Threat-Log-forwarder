#!/bin/bash

# Load environment variables from .env file
set -o allexport
source "$(dirname "$0")/.env"
set +o allexport

# Service names from docker-compose
LOGSTASH_SERVICE="nfg-logstash"
SYSLOG_SERVICE="nfg-syslog"

# All defined services (whether enabled or not)
ALL_SERVICES=("$LOGSTASH_SERVICE" "$SYSLOG_SERVICE")

# Services to start based on .env file
SERVICES_TO_START=()
[[ "$RUN_LOGSTASH" == "true" ]] && SERVICES_TO_START+=("$LOGSTASH_SERVICE")
[[ "$RUN_SYSLOG" == "true" ]] && SERVICES_TO_START+=("$SYSLOG_SERVICE")


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
