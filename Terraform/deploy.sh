#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

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

# Generate a secure .env file for sensitive environment variables
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating secure .env file..."
cat > .env <<EOF
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
DB_HOST=${rds_endpoint}
DB_PORT=5432
EOF
echo "[$(date '+%Y-%m-%d %H:%M:%S')] .env file created with sensitive environment variables"

# Generate a docker-compose.yml file with environment variables pulled from the .env file
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  db:
    image: postgres:14
    environment:
      - POSTGRES_DB=\${DB_NAME}
      - POSTGRES_USER=\${DB_USER}
      - POSTGRES_PASSWORD=\${DB_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${DB_USER} -d \${DB_NAME}"]
      interval: 5s
      timeout: 5s
      retries: 5

  backend:
    build: 
      context: ..
      dockerfile: Dockerfile.backend
    environment:
      - DEBUG=0
      - DB_NAME=\${DB_NAME}
      - DB_HOST=db
      - DB_USER=\${DB_USER}
      - DB_PASSWORD=\${DB_PASSWORD}
      - DB_PORT=\${DB_PORT}
      - PYTHONUNBUFFERED=1
    volumes:
      - ../backend:/app
      - static_volume:/app/static
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
    command: >
      bash -c "
        echo 'Running migrations...' &&
        python manage.py migrate &&
        python manage.py makemigrations account product payments &&
        python manage.py migrate &&
        python manage.py runserver 0.0.0.0:8000
      "

  frontend:
    build:
      context: ..
      dockerfile: Dockerfile.frontend
    ports:
      - "3000:3000"
    volumes:
      - ../frontend:/app
      - /app/node_modules
    depends_on:
      - backend

volumes:
  postgres_data:
  static_volume:
EOF
echo "[$(date '+%Y-%m-%d %H:%M:%S')] docker-compose.yml created"

# Run Docker Compose
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running Docker Compose..."
docker-compose up -d

# Clean up Docker resources
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning up Docker resources..."
docker system prune -f

# Log out of Docker Hub
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Logging out of Docker Hub..."
docker logout

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deployment completed successfully."
