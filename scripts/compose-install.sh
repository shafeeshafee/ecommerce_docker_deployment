#!/bin/bash

echo "🚀 Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

echo -e "\n📝 Setting permissions..."
sudo chmod +x /usr/local/bin/docker-compose

echo -e "\n✨ Installation complete!"
echo "To verify installation, run: docker-compose --version"