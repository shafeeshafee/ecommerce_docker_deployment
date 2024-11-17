#!/bin/bash

# Colors for pretty output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

print_banner() {
    echo -e "${BLUE}${BOLD}"
    echo "╔════════════════════════════════════════════╗"
    echo "║         Terraform Installation Script       ║"
    echo "║              for Ubuntu EC2                ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${GREEN}${BOLD}==> $1${NC}"
}

# Start installation
print_banner

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Update system packages
print_step "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required dependencies
print_step "Installing required dependencies..."
apt-get install -y gnupg software-properties-common curl

# Add HashiCorp GPG key
print_step "Adding HashiCorp GPG key..."
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add HashiCorp repository
print_step "Adding HashiCorp repository..."
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# Update package list again
print_step "Updating package list..."
apt-get update

# Install Terraform
print_step "Installing Terraform..."
apt-get install -y terraform

# Verify installation
print_step "Verifying installation..."
TERRAFORM_VERSION=$(terraform --version)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✔ Terraform installed successfully!${NC}"
    echo -e "Version: ${TERRAFORM_VERSION}"
    echo -e "\nYou can now use Terraform with the 'terraform' command."
else
    echo -e "\n❌ Installation failed. Please check the error messages above."
    exit 1
fi

# Add terraform autocomplete
print_step "Setting up Terraform autocomplete..."
terraform -install-autocomplete

echo -e "\n${BLUE}${BOLD}Installation complete!${NC}"
echo -e "Remember to log out and back in for autocomplete to take effect."