#!/bin/bash

# Purpose: Main deployment script that orchestrates the setup process

# Source utility functions
source "$(dirname "$0")/scripts/docker_setup.sh"
source "$(dirname "$0")/scripts/app_setup.sh"
source "$(dirname "$0")/scripts/node_exporter_setup.sh"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check last command status
check_status() {
    if [ $? -ne 0 ]; then
        log "ERROR: $1"
        exit 1
    fi
}

# Main deployment process
main() {
    log "Starting deployment process..."
    
    # Setup Docker environment
    setup_docker_environment
    check_status "Failed to setup Docker environment"
    
    # Setup application environment
    setup_application_environment "${docker_user}" "${docker_pass}" "${rds_address}" "${db_username}" "${db_password}" "${docker_compose}"
    check_status "Failed to setup application environment"
    
    # Setup Node Exporter for monitoring
    setup_node_exporter
    check_status "Failed to setup Node Exporter"
    
    log "Deployment completed successfully."
}

# Execute main function
main