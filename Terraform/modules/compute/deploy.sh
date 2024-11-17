#!/bin/bash

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

# Function to wait for service health
wait_for_service() {
    local service=$1
    local max_attempts=30
    local attempt=1
    
    log "Waiting for $service to be healthy..."
    while [ $attempt -le $max_attempts ]; do
        if docker-compose ps | grep -q "$service.*healthy"; then
            log "$service is healthy"
            return 0
        fi
        log "Attempt $attempt/$max_attempts: $service not yet healthy, waiting..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    log "ERROR: $service failed to become healthy after $max_attempts attempts"
    return 1
}

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

# Create docker config directory
mkdir -p /root/.docker

# Create docker config with auth
log "Setting up Docker Hub credentials..."
cat > /root/.docker/config.json <<EOF
{
    "auths": {
        "https://index.docker.io/v1/": {
            "auth": "$(echo -n "${docker_user}:${docker_pass}" | base64)"
        }
    }
}
EOF
chmod 600 /root/.docker/config.json

# Create app directory and set permissions
log "Creating app directories..."
mkdir -p /app/init
chmod 755 /app
cd /app || exit
log "Created and moved to /app directory"

# Create backend initialization script
log "Creating backend initialization script..."
cat > /app/init/backend-init.sh <<'EOF'
#!/bin/bash

echo 'Waiting for PostgreSQL...'
sleep 15

echo 'Running migrations for core apps...'
python manage.py migrate auth
python manage.py migrate admin
python manage.py migrate contenttypes
python manage.py migrate sessions

echo 'Making migrations for custom apps...'
python manage.py makemigrations account
python manage.py makemigrations product
python manage.py makemigrations payments

echo 'Running migrations for custom apps...'
python manage.py migrate account
python manage.py migrate product
python manage.py migrate payments

echo 'Creating superuser...'
echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'admin@example.com', 'admin123') if not User.objects.filter(username='admin').exists() else print('Superuser already exists')" | python manage.py shell

echo 'Loading initial data if needed...'
if [ ! -f /app/initial_data_loaded ]; then
    echo 'Dumping data from SQLite...'
    python manage.py dumpdata --database=sqlite --natural-foreign --natural-primary -e contenttypes -e auth.Permission --indent 4 > datadump.json
    echo 'Loading data into PostgreSQL...'
    python manage.py loaddata datadump.json
    touch /app/initial_data_loaded
fi

echo 'Starting server...'
python manage.py runserver 0.0.0.0:8000
EOF
chmod +x /app/init/backend-init.sh

# Create database initialization script
log "Creating database initialization script..."
cat > /app/init-db.sql <<EOF
CREATE DATABASE ecommerce;
EOF

# Create docker-compose.yml file
log "Creating docker-compose.yml..."
cat > docker-compose.yml <<EOF
${docker_compose}
EOF
chmod 644 /app/docker-compose.yml
log "docker-compose.yml created"

# Wait for RDS to be available and create database
log "Waiting for RDS to be available..."
for i in {1..30}; do
    if PGPASSWORD="${db_password}" psql -h "${rds_address}" -U "${db_username}" -c '\l' postgres >/dev/null 2>&1; then
        log "RDS is available, creating database..."
        PGPASSWORD="${db_password}" psql -h "${rds_address}" -U "${db_username}" -f /app/init-db.sql postgres
        break
    fi
    log "Waiting for RDS... attempt $i/30"
    sleep 10
done

# Wait for Docker to be ready
log "Waiting for Docker daemon..."
sleep 10

# Pull Docker images
log "Pulling Docker images..."
docker-compose pull
check_status "Failed to pull Docker images"

# Start Docker containers
log "Starting Docker containers..."
docker-compose up -d --force-recreate
check_status "Failed to start Docker containers"

# Wait for services to be healthy
wait_for_service "backend"
check_status "Backend service failed to become healthy"

wait_for_service "frontend"
check_status "Frontend service failed to become healthy"

# Clean up unused Docker resources
log "Cleaning up unused Docker resources..."
docker system prune -af --volumes
check_status "Failed to clean up Docker resources"

log "Deployment script completed successfully."