# Python API with Automated Deployment and Teardown

A production-oriented Python API application built with FastAPI, containerized with Docker, and deployed on AWS EC2 using Terraform.

## Overview

This project implements a RESTful API that:
- Maintains shared state in memory (counter and message)
- Provides endpoints for status, updates, and logs
- Persists update history in SQLite
- Supports optional API key authentication
- Automates infrastructure provisioning and teardown with Terraform

## Architecture

```
Local Machine
 └── Terraform
      ├── Creates EC2 Instance
      ├── Creates Security Group (IP-restricted)
      └── user_data bootstrap script
            └── Docker Engine
                 └── Python API Container
                       ├── FastAPI application
                       ├── In-memory shared state
                       └── SQLite database (logs)
```

## Components

| Component      | Technology         | Responsibility                             |
| -------------- | ------------------ | ------------------------------------------ |
| API            | FastAPI            | Expose REST endpoints, validation, logging |
| Container      | Docker             | Package and run the application            |
| Database       | SQLite             | Persist update logs                        |
| Infrastructure | Terraform          | Provision and destroy AWS resources        |
| Compute        | AWS EC2 (t3.micro) | Host the Docker container                  |

## Project Structure

```
.
├── app/                    # Application package
│   ├── __init__.py
│   ├── main.py             # FastAPI application entry point
│   ├── models.py            # Pydantic models for validation
│   ├── routes.py            # API endpoints and routes
│   ├── state.py             # Shared state management
│   ├── database.py          # SQLite database operations
│   └── auth.py              # API key authentication
├── requirements.txt         # Python dependencies
├── Dockerfile               # Multi-stage Docker build
├── .dockerignore            # Docker build exclusions
├── .gitignore               # Git exclusions
├── terraform/               # Terraform configuration
│   ├── provider.tf          # AWS provider configuration
│   ├── main.tf              # EC2 instance and security group
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values (public IP, instance ID)
│   ├── user_data.sh         # Bootstrap script for EC2
│   ├── deploy.sh            # Deployment script
│   └── teardown.sh          # Teardown script
├── design_review.md         # Complete design specifications
└── README.md                # This file
```

## API Endpoints

### GET /status

Returns the current state and metadata.

**Response:**
```json
{
  "state": {
    "counter": 42,
    "message": "Hello from AWS!"
  },
  "timestamp": "2025-12-31T12:34:54.689929+00:00",
  "uptime_seconds": 113
}
```

### POST /update

Updates the shared state (counter and/or message). Requires at least one field to be provided.

**Request Body:**
```json
{
  "counter": 42,
  "message": "Hello from AWS!"
}
```

**Response:**
```json
{
  "state": {
    "counter": 42,
    "message": "Hello from AWS!"
  }
}
```

**Authentication:** Optional API key via `X-API-KEY` header (if `API_KEY` environment variable is set)

**Error Responses:**
- `400` - Validation error (e.g., no fields provided)
- `401` - Invalid or missing API key (if authentication is enabled)

### GET /logs

Returns paginated update history.

**Query Parameters:**
- `page` (default: 1, minimum: 1) - Page number (1-indexed)
- `limit` (default: 10, minimum: 1, maximum: 100) - Number of records per page

**Example:**
```bash
curl "http://<PUBLIC_IP>:5000/logs?page=1&limit=10"
```

**Response:**
```json
{
  "logs": [
    {
      "id": 1,
      "timestamp": "2025-12-31T12:34:40.839458+00:00",
      "old_value": {
        "counter": 0,
        "message": "initial"
      },
      "new_value": {
        "counter": 42,
        "message": "Hello from AWS!"
      }
    }
  ],
  "page": 1,
  "limit": 10,
  "total": 1
}
```

### Interactive API Documentation

FastAPI automatically provides interactive API documentation:
- **Swagger UI**: `http://<PUBLIC_IP>:5000/docs`
- **ReDoc**: `http://<PUBLIC_IP>:5000/redoc`

## Prerequisites

### Required Software

1. **Python 3.9+** - For local development
2. **Docker** - For containerization and local testing
3. **Terraform** (>= 1.0) - For infrastructure provisioning
4. **AWS CLI** - For AWS authentication and verification

### AWS Requirements

1. **AWS Account** - With appropriate permissions
2. **AWS Credentials** - Configured via `aws configure` or environment variables
3. **IAM Permissions** - Your AWS user/role needs the following permissions:
   - `ec2:RunInstances`
   - `ec2:CreateSecurityGroup`
   - `ec2:DescribeInstances`
   - `ec2:DescribeImages`
   - `ec2:DescribeSecurityGroups`
   - `ec2:TerminateInstances`
   - `ec2:DeleteSecurityGroup`
   - `ec2:AuthorizeSecurityGroupIngress`
   - `ec2:RevokeSecurityGroupIngress`

   **Quick Setup:** Attach the `AmazonEC2FullAccess` policy to your IAM user/role for full EC2 permissions.

### Installation

**macOS (using Homebrew):**
```bash
# Install Terraform
brew install terraform

# Install AWS CLI
brew install awscli

# Install Docker Desktop
brew install --cask docker
```

**Linux:**
```bash
# Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Docker
sudo apt-get update
sudo apt-get install docker.io
```

## Local Development

### 1. Create Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Run the Application

```bash
uvicorn app.main:app --host 0.0.0.0 --port 5000 --reload
```

The API will be available at `http://localhost:5000`

### 4. Test with Docker Locally

```bash
# Build the Docker image
docker build -t python-api .

# Run the container
docker run -p 5000:5000 python-api
```

## Deployment with Terraform

### 1. Configure AWS Credentials

```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `us-east-1`)
- Default output format (e.g., `json`)

### 2. Deploy to AWS

**Option A: Use deploy script (recommended)**
```bash
cd terraform
./deploy.sh
```

**Option B: Manual deployment**
```bash
cd terraform
MY_IP=$(curl -s https://checkip.amazonaws.com)
terraform init
terraform apply -var="my_ip=$MY_IP"
```

The script will:
1. Automatically detect your public IP address
2. Initialize Terraform
3. Create EC2 instance (Ubuntu 22.04 LTS, t3.micro)
4. Create security group (allows port 5000 from your IP only)
5. Install Docker and deploy the application via user_data script
6. Output the public IP address

**Note:** Wait 2-3 minutes after deployment for the instance to boot and the application to start.

### 3. Test the Deployed API

After deployment, Terraform will output the public IP address. Use it to test:

```bash
# Get the public IP
PUBLIC_IP=$(cd terraform && terraform output -raw public_ip)

# Test endpoints
curl http://$PUBLIC_IP:5000/status
curl -X POST http://$PUBLIC_IP:5000/update \
  -H "Content-Type: application/json" \
  -d '{"counter": 42, "message": "Hello from AWS!"}'
curl http://$PUBLIC_IP:5000/status
curl "http://$PUBLIC_IP:5000/logs?page=1&limit=10"
```

Or open in browser: `http://$PUBLIC_IP:5000/docs`

## Teardown with Terraform

To destroy all AWS resources and stop incurring charges:

**Option A: Use teardown script (recommended)**
```bash
cd terraform
./teardown.sh
```

**Option B: Manual teardown**
```bash
cd terraform
MY_IP=$(curl -s https://checkip.amazonaws.com)
terraform destroy -var="my_ip=$MY_IP"
```

This will:
- Terminate the EC2 instance
- Delete the security group
- Remove all associated resources

**Warning:** All data (state and logs) will be permanently deleted.

## Security

### Network Security

- **EC2 Security Group**: Restricts inbound traffic to port 5000 from the Terraform runner's IP address only (`/32` CIDR)
- **Outbound Traffic**: All outbound traffic is allowed (for package installation and Docker image pulls)

### API Security

- **Optional API Key Authentication**: If the `API_KEY` environment variable is set in the container, the `POST /update` endpoint requires an `X-API-KEY` header
- **No Authentication by Default**: If `API_KEY` is not set, authentication is disabled (suitable for development/testing)

### Best Practices

- Security group is automatically configured to only allow access from your IP
- API key is passed via environment variable (not hardcoded)
- Docker image uses multi-stage build to minimize attack surface
- Application runs as non-root user in container

## Design Decisions and Trade-offs

### Architecture Decisions

1. **FastAPI vs Flask**
   - **Choice**: FastAPI
   - **Rationale**: Built-in validation, automatic OpenAPI documentation, async support, and type hints make it ideal for modern Python APIs

2. **Modular Structure vs Single File**
   - **Choice**: Modular structure (separate files for models, routes, database, auth)
   - **Rationale**: Better code organization, maintainability, and testability. Follows separation of concerns principle.

3. **SQLite vs External Database**
   - **Choice**: SQLite
   - **Rationale**: Sufficient for the task scope, no external dependencies, lightweight, and perfect for single-instance deployments

4. **In-Memory State vs Persistent State**
   - **Choice**: In-memory state
   - **Rationale**: Acceptable trade-off for simplicity. State resets on container restart, but update history is persisted in SQLite.

5. **Ubuntu vs Amazon Linux 2**
   - **Choice**: Ubuntu 22.04 LTS
   - **Rationale**: More familiar to developers, better package availability, and broader community support. Dynamically fetched AMI ensures latest security patches.

6. **Terraform user_data vs Configuration Management**
   - **Choice**: user_data script
   - **Rationale**: Keeps automation minimal and self-contained. No need for Ansible, Chef, or Puppet. Docker handles application packaging.

7. **Multi-Stage Docker Build**
   - **Choice**: Multi-stage build
   - **Rationale**: Significantly reduces final image size by excluding build dependencies. Improves security and deployment speed.

8. **t3.micro vs t2.micro**
   - **Choice**: t3.micro
   - **Rationale**: Free tier eligible, better performance with burstable CPU credits, and more modern instance type.

9. **IP Whitelisting vs Public Access**
   - **Choice**: IP whitelisting
   - **Rationale**: Basic security measure to prevent unauthorized access. Only the Terraform runner can access the API.

10. **Optional API Key Authentication**
    - **Choice**: Optional (enabled via environment variable)
    - **Rationale**: Flexible for different deployment scenarios. Can be enabled for production or disabled for testing.

### Limitations and Future Improvements

- **Single Instance**: No high availability or load balancing
- **No CI/CD**: Manual deployment process
- **No Monitoring**: No CloudWatch integration or health checks
- **No Auto-Scaling**: Fixed instance size
- **State Persistence**: In-memory state is lost on restart (logs persist)
- **No HTTPS**: HTTP only (would need load balancer or reverse proxy for HTTPS)
- **No Secrets Management**: API key stored as environment variable (could use AWS Secrets Manager)

## Troubleshooting

### Deployment Issues

**Error: "UnauthorizedOperation"**
- **Solution**: Ensure your AWS IAM user has the required EC2 permissions (see Prerequisites)

**Error: "Instance type not eligible for Free Tier"**
- **Solution**: The default instance type is `t3.micro` which is free tier eligible. If you see this error, check your AWS account's free tier status.

**Error: "Cannot connect to API after deployment"**
- **Solution**: 
  1. Wait 2-3 minutes for the instance to fully boot and deploy
  2. Verify your IP hasn't changed (security group only allows your IP)
  3. Check EC2 instance status in AWS Console
  4. Verify security group rules allow port 5000 from your IP

**Error: "AMI not found"**
- **Solution**: The Terraform configuration dynamically fetches the latest Ubuntu 22.04 LTS AMI. Ensure you have `ec2:DescribeImages` permission.

### Local Development Issues

**Port 5000 already in use**
- **Solution**: 
  ```bash
  # Find process using port 5000
  lsof -i :5000
  # Kill the process or use a different port
  uvicorn app:app --host 0.0.0.0 --port 5001
  ```

**Docker daemon not running**
- **Solution**: Start Docker Desktop or Docker daemon

## Additional Resources

- **Design Document**: See `design_review.md` for complete design specifications and implementation plan
- **FastAPI Documentation**: https://fastapi.tiangolo.com/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **Docker Documentation**: https://docs.docker.com/

## License

This project is provided as-is for educational and demonstration purposes.
