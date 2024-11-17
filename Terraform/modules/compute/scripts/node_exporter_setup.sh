#!/bin/bash

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
