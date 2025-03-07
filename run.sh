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

# Function to start services
start_services() {
    if [[ ${#SERVICES_TO_START[@]} -eq 0 ]]; then
        echo "No services enabled to run. Exiting."
        exit 0
    fi
    echo "Starting services: ${SERVICES_TO_START[*]}"
    docker compose up -d "${SERVICES_TO_START[@]}"
}

# Function to stop running services (even if disabled in .env)
stop_services() {
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
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
