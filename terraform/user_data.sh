#!/bin/bash

# Update system packages (Ubuntu uses apt)
apt-get update -y

# Install required packages
apt-get install -y docker.io git

# Start Docker service
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group (Ubuntu uses 'ubuntu' user)
usermod -a -G docker ubuntu

# Wait a moment for Docker to be ready
sleep 5

# Create application directory
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app

# Clone repository from GitHub
echo "Cloning repository from GitHub..."
if [[ "${github_repo}" == https://github.com/* ]]; then
  # Construct URL with token for authentication
  # Replace https://github.com/ with https://TOKEN@github.com/
  REPO_URL=$(echo "${github_repo}" | sed "s|https://github.com/|https://${github_token}@github.com/|")
  git clone "$REPO_URL" . || {
    echo "Failed to clone repository. Check GitHub token and repository URL."
    exit 1
  }
else
  # Handle other Git URLs (SSH, etc.)
  git clone "${github_repo}" . || {
    echo "Failed to clone repository."
    exit 1
  }
fi

# Build Docker image
echo "Building Docker image..."
docker build -t python-api:latest .

# Stop and remove any existing container with the same name
docker stop python-api 2>/dev/null || true
docker rm python-api 2>/dev/null || true

# Run Docker container
echo "Starting Docker container..."
docker run -d \
  --name python-api \
  --restart unless-stopped \
  -p 5000:5000 \
  python-api:latest

# Wait a moment for the container to start
sleep 5

# Check if container is running
if docker ps | grep -q python-api; then
    echo "✅ Application deployed successfully!"
    echo "API is running on port 5000"
else
    echo "❌ Container failed to start. Check logs with: docker logs python-api"
    exit 1
fi
