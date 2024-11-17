#!/bin/bash
# File: scripts/app_setup.sh
# Purpose: Handles application setup and deployment

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
    setup_app_directories
    setup_ssh_keys  # Added SSH key setup
    create_initialization_scripts "${rds_address}" "${db_username}" "${db_password}" "${docker_compose}"
    setup_systemd_service
    
    # Deploy application
    deploy_application "${rds_address}" "${db_username}" "${db_password}"
}

setup_ssh_keys() {
    log "Setting up SSH authorized keys..."
    
    # Ensure .ssh directory exists with correct permissions
    mkdir -p /home/ubuntu/.ssh
    chmod 700 /home/ubuntu/.ssh
    
    # Add the public key to authorized_keys
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDSkMc19m28614Rb3sGEXQUN+hk4xGiufU9NYbVXWGVrF1bq6dEnAD/VtwM6kDc8DnmYD7GJQVvXlDzvlWxdpBaJEzKziJ+PPzNVMPgPhd01cBWPv82+/Wu6MNKWZmi74TpgV3kktvfBecMl+jpSUMnwApdA8Tgy8eB0qELElFBu6cRz+f6Bo06GURXP6eAUbxjteaq3Jy8mV25AMnIrNziSyQ7JOUJ/CEvvOYkLFMWCF6eas8bCQ5SpF6wHoYo/8iavMP4ChZaXF754OJ5jEIwhuMetBFXfnHmwkrEIInaF3APIBBCQWL5RC4sJA36yljZCGtzOi5Y2jq81GbnBXN3Dsjvo5h9ZblG4uWfEzA2Uyn0OQNDcrecH3liIpowtGAoq8NUQf89gGwuOvRzzILkeXQ8DKHtWBee5Oi/z7j9DGfv7hTjDBQkh28LbSu9RdtPRwcCweHwTLp4X3CYLwqsxrIP8tlGmrVoZZDhMfyy/bGslZp5Bod2wnOMlvGktkHs=" >> /home/ubuntu/.ssh/authorized_keys
    
    # Set correct permissions for authorized_keys
    chmod 600 /home/ubuntu/.ssh/authorized_keys
    chown -R ubuntu:ubuntu /home/ubuntu/.ssh
    
    check_status "Failed to setup SSH keys"
}

setup_app_directories() {
    log "Creating app directories..."
    mkdir -p /app/init
    chmod 755 /app
    cd /app || exit
    log "Created and moved to /app directory"
}

create_initialization_scripts() {
    local rds_address="$1"
    local db_username="$2"
    local db_password="$3"
    local docker_compose="$4"

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
    create_backend_init_script
}

create_backend_init_script() {
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
}

setup_systemd_service() {
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
}

deploy_application() {
    local rds_address="$1"
    local db_username="$2"
    local db_password="$3"

    # Wait for RDS to be available and create database
    wait_for_rds "${rds_address}" "${db_username}" "${db_password}"
    
    # Deploy containers
    deploy_containers
}

wait_for_rds() {
    local rds_address="$1"
    local db_username="$2"
    local db_password="$3"

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
}

deploy_containers() {
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