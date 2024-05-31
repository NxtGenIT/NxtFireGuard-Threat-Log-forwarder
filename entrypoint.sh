#!/bin/bash
# replaces the X_API_KEY_PLACEHOLDER in syslog-ng.conf with the X_API_KEY variable from the docker-compose.yml and starts the syslog service
awk -v xapikey="$X_API_KEY" -v xhost="$X_HOST" '{
    gsub(/X_API_KEY_PLACEHOLDER/, xapikey);
    print;
}' /etc/syslog-ng/syslog-ng.conf > /tmp/syslog-ng.conf.tmp && cat /tmp/syslog-ng.conf.tmp > /etc/syslog-ng/syslog-ng.conf

# Start syslog-ng in the foreground
exec syslog-ng -F --no-caps