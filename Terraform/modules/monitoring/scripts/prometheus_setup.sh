#!/bin/bash

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

setup_prometheus() {
    log "Installing Prometheus..."
    
    # Install Prometheus
    apt-get update
    apt-get install -y prometheus jq
    
    # Configure Prometheus
    log "Configuring Prometheus..."
    
    # Parse the JSON array of IPs and create the targets string
    TARGETS=$(echo '${app_ips}' | jq -r '.[]' | while read ip; do
        echo -n "'$ip:9100',"
    done | sed 's/,$//')
    
    # Create Prometheus config
    cat > /etc/prometheus/prometheus.yml <<EOL
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: [$TARGETS]
    
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOL
    
    # Set correct permissions
    chown -R prometheus:prometheus /etc/prometheus
    
    # Restart Prometheus
    log "Restarting Prometheus service..."
    systemctl restart prometheus
    systemctl enable prometheus
    
    log "Prometheus setup completed"
}

# Execute the setup
setup_prometheus