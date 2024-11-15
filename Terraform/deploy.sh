#!/bin/bash

# Update apt packages
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Updating apt packages..."
sudo apt-get update

# Install Docker dependencies
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Installing Docker dependencies..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker’s official GPG key
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Adding Docker's GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the stable repository
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Setting up Docker repository..."
echo \
  "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and Docker Compose
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Installing Docker Engine and Docker Compose..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose standalone
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Installing Docker Compose standalone..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.30.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add current user to docker group
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Adding current user to docker group..."
sudo usermod -aG docker \$USER

# Log into Docker Hub
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Logging into Docker Hub..."
echo "${docker_pass}" | sudo docker login -u "${docker_user}" --password-stdin

# Create app directory and move into it
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Creating app directory..."
sudo mkdir -p /app
cd /app
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Moved to /app directory."

# Create docker-compose.yml file
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Creating docker-compose.yml..."
cat > docker-compose.yml <<EOF
${docker_compose}
EOF
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] docker-compose.yml created."

# Pull Docker images
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Pulling Docker images..."
sudo docker-compose pull

# Start Docker containers
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Starting Docker containers..."
sudo docker-compose up -d --force-recreate

# Clean up unused Docker resources
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Cleaning up unused Docker resources..."
sudo docker system prune -af

# Log out of Docker Hub
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Logging out of Docker Hub..."
sudo docker logout

echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Deployment script completed successfully."
