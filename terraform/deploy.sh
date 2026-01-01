#!/bin/bash
# Simple deployment script

# Load environment variables from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
    # Source .env file, handling comments and empty lines properly
    set -a
    # Read .env file, skip comments and empty lines, export variables
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        # Export the variable
        export "$line"
    done < "$PROJECT_ROOT/.env"
    set +a
else
    echo "Error: .env file not found in project root"
    echo "Please create .env file based on .env.example"
    exit 1
fi

# Check for required variables
if [ -z "$GITHUB_USERNAME" ]; then
    echo "Error: GITHUB_USERNAME is required in .env file"
    exit 1
fi

if [ -z "$GITHUB_REPO_NAME" ]; then
    echo "Error: GITHUB_REPO_NAME is required in .env file"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN is required in .env file"
    exit 1
fi

# Construct full GitHub repository URL
GITHUB_REPO="https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO_NAME}.git"

# API key is optional - if not set, authentication will be disabled
API_KEY="${API_KEY:-}"

MY_IP=$(curl -s https://checkip.amazonaws.com)
cd "$SCRIPT_DIR"
terraform init

# Build terraform apply command
TERRAFORM_CMD="terraform apply \
  -var=\"my_ip=$MY_IP\" \
  -var=\"github_repo=$GITHUB_REPO\" \
  -var=\"github_token=$GITHUB_TOKEN\""

# Add API key if provided
if [ -n "$API_KEY" ]; then
  TERRAFORM_CMD="$TERRAFORM_CMD -var=\"api_key=$API_KEY\""
fi

# Execute terraform apply
eval "$TERRAFORM_CMD -auto-approve"

