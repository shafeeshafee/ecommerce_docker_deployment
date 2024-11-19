#!/bin/bash

# Create reports directory
mkdir -p /home/ubuntu/reports

# 1. Install Trivy
echo "Installing Trivy..."
sudo apt-get update
sudo apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy

# 2. Install Python venv and Checkov
echo "Installing Python venv and Checkov..."
sudo apt-get install -y python3-venv
python3 -m venv /home/ubuntu/security-venv
source /home/ubuntu/security-venv/bin/activate
pip install --upgrade pip
pip install checkov
deactivate

# 3. Install OWASP ZAP
echo "Installing OWASP ZAP..."
wget https://github.com/zaproxy/zaproxy/releases/download/v2.15.0/ZAP_2_15_0_unix.sh -O zap_install.sh
chmod +x zap_install.sh
sudo ./zap_install.sh -q -dir /opt/zap
rm zap_install.sh

# 4. Install sonar-scanner
echo "Installing sonar-scanner..."
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-linux.zip
unzip sonar-scanner-cli-4.8.0.2856-linux.zip
sudo mv sonar-scanner-4.8.0.2856-linux /opt/sonar-scanner
echo 'export PATH=$PATH:/opt/sonar-scanner/bin' | sudo tee -a /etc/profile.d/sonar-scanner.sh

# Set correct permissions
sudo chown -R ubuntu:ubuntu /home/ubuntu/security-venv
sudo chown -R ubuntu:ubuntu /home/ubuntu/reports

echo "Security tools installation complete!" 
