#!/bin/bash
# File: scripts/docker_setup.sh
# Purpose: Handles Docker installation and configuration

setup_docker_environment() {
    # Update apt packages
    log "Updating apt packages..."
    apt-get update
    check_status "Failed to update apt packages"

    # Install required packages
    log "Installing prerequisites..."
    apt-get install -y ca-certificates curl gnupg postgresql-client
    check_status "Failed to install prerequisites"

    # Add Docker's official GPG key
    log "Adding Docker's GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    check_status "Failed to add Docker's GPG key"

    # Set up the Docker repository
    log "Setting up Docker repository..."
    echo \
      "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    check_status "Failed to set up Docker repository"

    # Update apt and install Docker Engine
    log "Installing Docker Engine..."
    apt-get update
    check_status "Failed to update apt after adding Docker repository"

    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    check_status "Failed to install Docker"

    # Start and enable Docker service
    log "Starting Docker service..."
    systemctl start docker
    systemctl enable docker
    check_status "Failed to start Docker service"

    # Install Docker Compose standalone
    log "Installing Docker Compose standalone..."
    curl -L "https://github.com/docker/compose/releases/download/v2.23.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    check_status "Failed to install Docker Compose"
}