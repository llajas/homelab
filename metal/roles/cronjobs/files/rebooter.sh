#!/bin/bash

LOG_FILE="/var/log/rebooter_check.log"

# Function to log messages
log_message() {
    # Set the TZ environment variable to America/Chicago
    echo "$(TZ='America/Chicago' date '+%Y-%m-%d %H:%M:%S %Z'): $1" >> "$LOG_FILE"
}

# Check if /var/run/reboot-required exists
if [ -f "/var/run/reboot-required" ]; then
    log_message "Reboot required due to /var/run/reboot-required file."
    exit 0
fi

# Alternatively, use needs-restarting to check if a reboot is needed
if ! needs-restarting --reboothint; then
    log_message "No reboot needed according to needs-restarting."
    exit 0
fi

# Default exit, meaning no reboot required
log_message "No reboot required."
exit 1
