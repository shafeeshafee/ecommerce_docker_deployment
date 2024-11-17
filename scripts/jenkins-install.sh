#!/usr/bin/env bash

# Colors for pretty output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

print_banner() {
    echo -e "${BLUE}${BOLD}"
    echo "╔════════════════════════════════════════════╗"
    echo "║           Jenkins Installation Script      ║"
    echo "║              for Ubuntu EC2                ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${GREEN}${BOLD}==> $1${NC}"
}

# Start script
print_banner

# Update the package manager
print_step "Updating package manager..."
sudo apt update -y

# Install Java (Java 17 is required for Jenkins)
print_step "Installing OpenJDK 17..."
sudo apt install openjdk-17-jdk -y

# Add the Jenkins Debian repository and import the GPG key
print_step "Adding Jenkins repository and GPG key..."
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package manager to include Jenkins packages
print_step "Updating package manager to include Jenkins packages..."
sudo apt update -y

# Install Jenkins
print_step "Installing Jenkins..."
sudo apt install jenkins -y

# Start and enable Jenkins service
print_step "Starting and enabling Jenkins service..."
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Output Jenkins initial admin password
print_step "Jenkins installation complete!"
echo -e "${GREEN}${BOLD}✔ Jenkins installed successfully!${NC}"
echo -e "To retrieve the initial admin password, use:"
echo -e "${BLUE}sudo cat /var/lib/jenkins/secrets/initialAdminPassword${NC}"