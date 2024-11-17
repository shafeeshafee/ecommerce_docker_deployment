#!/bin/bash

echo "🐳 Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

echo -e "\n🔧 Adding current user to docker group..."
sudo usermod -aG docker $USER

echo -e "\n✨ Installation complete!"
echo "Please log out and back in for changes to take effect."
echo -e "\nTo verify installation, run: docker --version"