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

setup_application_environment() {
    local docker_user="$1"
    local docker_pass="$2"
    local rds_address="$3"
    local db_username="$4"
    local db_password="$5"
    local docker_compose="$6"

    # Create docker config with auth
    log "Setting up Docker Hub credentials..."
    mkdir -p /root/.docker
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

    # Setup application directories and files
    log "Creating app directories..."
    mkdir -p /app/init
    chmod 755 /app
    cd /app || exit
    log "Created and moved to /app directory"

    # Setup SSH keys
    log "Setting up SSH authorized keys..."
    mkdir -p /home/ubuntu/.ssh
    chmod 700 /home/ubuntu/.ssh
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDSkMc19m28614Rb3sGEXQUN+hk4xGiufU9NYbVXWGVrF1bq6dEnAD/VtwM6kDc8DnmYD7GJQVvXlDzvlWxdpBaJEzKziJ+PPzNVMPgPhd01cBWPv82+/Wu6MNKWZmi74TpgV3kktvfBecMl+jpSUMnwApdA8Tgy8eB0qELElFBu6cRz+f6Bo06GURXP6eAUbxjteaq3Jy8mV25AMnIrNziSyQ7JOUJ/CEvvOYkLFMWCF6eas8bCQ5SpF6wHoYo/8iavMP4ChZaXF754OJ5jEIwhuMetBFXfnHmwkrEIInaF3APIBBCQWL5RC4sJA36yljZCGtzOi5Y2jq81GbnBXN3Dsjvo5h9ZblG4uWfEzA2Uyn0OQNDcrecH3liIpowtGAoq8NUQf89gGwuOvRzzILkeXQ8DKHtWBee5Oi/z7j9DGfv7hTjDBQkh28LbSu9RdtPRwcCweHwTLp4X3CYLwqsxrIP8tlGmrVoZZDhMfyy/bGslZp5Bod2wnOMlvGktkHs=" >> /home/ubuntu/.ssh/authorized_keys
    chmod 600 /home/ubuntu/.ssh/authorized_keys
    chown -R ubuntu:ubuntu /home/ubuntu/.ssh
    check_status "Failed to setup SSH keys"

    # Create docker-compose.yml
    log "Creating docker-compose.yml..."
    cat > docker-compose.yml <<EOF
${docker_compose}
EOF
    chmod 644 /app/docker-compose.yml
    
    # Create database initialization script
    log "Creating database initialization script..."
    cat > /app/init-db.sql <<EOF
CREATE DATABASE ecommerce;
EOF

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

    # Create systemd service
    log "Creating systemd service for docker-compose..."
    cat > /etc/systemd/system/docker-compose-app.service <<EOF
[Unit]
Description=Docker Compose Application Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/app
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the systemd service
    systemctl enable docker-compose-app
    systemctl start docker-compose-app
    check_status "Failed to enable docker-compose service"

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

    # Pull and start containers
    log "Pulling Docker images..."
    docker-compose pull
    check_status "Failed to pull Docker images"

    log "Starting Docker containers..."
    docker-compose up -d --force-recreate
    check_status "Failed to start Docker containers"

    # Wait for services to be healthy
    wait_for_service "backend"
    check_status "Backend service failed to become healthy"

    wait_for_service "frontend"
    check_status "Frontend service failed to become healthy"

    # Clean up
    log "Cleaning up unused Docker resources..."
    docker system prune -af --volumes
    check_status "Failed to clean up Docker resources"
}

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

setup_node_exporter() {
    log "Installing Node Exporter..."
    
    # Download and install Node Exporter
    cd /tmp
    curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
    tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
    mv node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
    
    # Create Node Exporter user
    useradd --no-create-home --shell /bin/false node_exporter
    
    # Create systemd service
    cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
    
    # Start and enable Node Exporter
    systemctl daemon-reload
    systemctl start node_exporter
    systemctl enable node_exporter
    
    # Clean up
    rm -rf /tmp/node_exporter*
    
    log "Node Exporter installation completed"
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