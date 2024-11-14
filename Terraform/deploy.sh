#!/bin/bash
set -e  # Exit on any error

# Install Docker
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing Docker..."
sudo apt-get update
sudo apt-get install -y docker.io

# Install Docker Compose
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.30.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add current user to docker group to avoid using sudo
sudo usermod -aG docker ubuntu
newgrp docker

# Log into Docker Hub
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Logging into Docker Hub..."
docker login -u "${docker_user}" -p "${docker_pass}"

# Create and setup application directory
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating app directory..."
mkdir -p /app
cd /app
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Created and moved to /app"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating docker-compose.yml..."
cat > docker-compose.yml <<EOF
${docker_compose}
EOF
echo "[$(date '+%Y-%m-%d %H:%M:%S')] docker-compose.yml created"

# Pull Docker images
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pulling Docker images..."
docker-compose pull

# Start application containers
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting application containers..."
docker-compose up -d --force-recreate

# Clean up Docker resources
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning up Docker resources..."
docker system prune -f

# Log out of Docker Hub
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Logging out of Docker Hub..."
docker logout

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deployment completed successfully."