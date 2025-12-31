#!/bin/bash

# Teardown script - Destroys all AWS resources created by Terraform
# Usage: ./teardown.sh

set -e

echo "=========================================="
echo "Terraform Teardown - Destroying Resources"
echo "=========================================="
echo ""

# Check if we're in the terraform directory
if [ ! -f "main.tf" ]; then
    echo "❌ Error: Please run this script from the terraform directory"
    echo "   cd terraform && ./teardown.sh"
    exit 1
fi

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "⚠️  Terraform not initialized. Running terraform init..."
    terraform init
fi

# Get current IP
MY_IP=$(curl -s https://checkip.amazonaws.com 2>/dev/null || echo "")

if [ -z "$MY_IP" ]; then
    echo "⚠️  Warning: Could not automatically detect your IP"
    echo "   You'll need to provide it manually"
    read -p "Enter your IP address (or press Enter to skip): " MY_IP
fi

# Show what will be destroyed
echo ""
echo "Resources that will be destroyed:"
echo "  - EC2 Instance (python-api-instance)"
echo "  - Security Group (python-api-sg)"
echo ""

# Confirm before destroying
read -p "Are you sure you want to destroy all resources? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo "Destroying resources..."

# Run terraform destroy
if [ -n "$MY_IP" ]; then
    terraform destroy -var="my_ip=$MY_IP" -auto-approve
else
    terraform destroy -auto-approve
fi

# Check exit status
if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Teardown Complete!"
    echo "=========================================="
    echo ""
    echo "All resources have been destroyed:"
    echo "  ✅ EC2 Instance terminated"
    echo "  ✅ Security Group deleted"
    echo ""
    echo "You can verify in AWS Console that no resources remain."
else
    echo ""
    echo "=========================================="
    echo "❌ Teardown Failed"
    echo "=========================================="
    echo ""
    echo "Some resources may not have been destroyed."
    echo "Check the error messages above and AWS Console."
    exit 1
fi

