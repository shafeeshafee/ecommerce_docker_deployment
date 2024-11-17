#!/bin/bash

echo "🚀 Installing AWS CLI v2 on Ubuntu EC2..."

# Install unzip if not present
echo "📦 Installing prerequisites..."
sudo apt update
sudo apt install -y unzip curl

# Download and install AWS CLI
echo -e "\n📥 Downloading AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

echo "📂 Extracting AWS CLI..."
unzip -q awscliv2.zip

echo "🔧 Installing AWS CLI..."
sudo ./aws/install

# Cleanup
echo "🧹 Cleaning up..."
rm -rf aws awscliv2.zip

echo -e "\n✨ Installation complete!"
aws --version

echo -e "\n💡 Next steps:"
echo "1. Configure AWS CLI with: aws configure"
echo "2. You'll need your AWS Access Key ID and Secret Access Key"