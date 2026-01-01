#!/bin/bash
# Simple teardown script

# Load environment variables from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# GitHub variables are optional for teardown, but try to load from .env if it exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    export $(cat "$PROJECT_ROOT/.env" | grep -v '^#' | xargs)
    if [ -n "$GITHUB_USERNAME" ] && [ -n "$GITHUB_REPO_NAME" ]; then
        GITHUB_REPO="https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO_NAME}.git"
    else
        GITHUB_REPO="https://github.com/placeholder/repo.git"
    fi
    GITHUB_TOKEN=${GITHUB_TOKEN:-"placeholder"}
else
    # Use placeholders if .env doesn't exist
    GITHUB_REPO="https://github.com/placeholder/repo.git"
    GITHUB_TOKEN="placeholder"
fi

# API key is optional for teardown
API_KEY=${API_KEY:-""}

MY_IP=$(curl -s https://checkip.amazonaws.com)
cd "$SCRIPT_DIR"

# Build terraform destroy command
TERRAFORM_CMD="terraform destroy \
  -var=\"my_ip=$MY_IP\" \
  -var=\"github_repo=$GITHUB_REPO\" \
  -var=\"github_token=$GITHUB_TOKEN\""

# Add API key if provided
if [ -n "$API_KEY" ]; then
  TERRAFORM_CMD="$TERRAFORM_CMD -var=\"api_key=$API_KEY\""
fi

# Execute terraform destroy
eval "$TERRAFORM_CMD -auto-approve"

