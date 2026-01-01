# Python API with Automated Deployment and Teardown

A production-oriented Python API application built with FastAPI, containerized with Docker, and deployed on AWS EC2 using Terraform.

## Overview

This project implements a RESTful API that:
- Maintains shared state in memory (counter and message)
- Provides endpoints for status, updates, and logs
- Persists update history in SQLite
- Supports optional API key authentication
- Automates infrastructure provisioning and teardown with Terraform
- **Deploys code from GitHub** - No hardcoded application files

## Quick Start

1. **Create GitHub token** at https://github.com/settings/tokens
2. **Create `.env` file** in project root:
   ```bash
   GITHUB_USERNAME=your-username
   GITHUB_REPO_NAME=Terraform-Python-API
   GITHUB_TOKEN=ghp_your_token_here
   ```
3. **Configure AWS**: `aws configure`
4. **Push code to GitHub** (if not already done)
5. **Deploy**: `cd terraform && ./deploy.sh`
6. **Test**: Wait 2-3 minutes, then visit `http://$(terraform output -raw public_ip):5000/docs`

## Application Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    FastAPI Application                   │
│                      (app/main.py)                       │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
    ┌────▼────┐            ┌────▼────┐
    │ Routes  │            │  Auth   │
    │(routes) │            │  (auth)  │
    └────┬────┘            └────┬────┘
         │                      │
    ┌────┴──────────────────────┴────┐
    │                                 │
┌───▼────┐  ┌──────────┐  ┌─────────▼──┐
│ Models │  │  State   │  │  Database  │
│(models)│  │ (state)  │  │(database)  │
└────────┘  └──────────┘  └────────────┘
```

### Application Components

| Component | File | Responsibility |
|-----------|------|---------------|
| **FastAPI App** | `app/main.py` | Application entry point, registers routes, handles exceptions |
| **Routes** | `app/routes.py` | API endpoints: `/status`, `/update`, `/logs` |
| **Models** | `app/models.py` | Pydantic models for request validation |
| **State** | `app/state.py` | In-memory shared state (counter, message) |
| **Database** | `app/database.py` | SQLite operations for logging updates |
| **Auth** | `app/auth.py` | Optional API key authentication |

### Application Flow

#### GET /status Flow
```
Client Request
    ↓
FastAPI Router (routes.py)
    ↓
Read from State (state.py)
    ↓
Calculate uptime from start_timestamp
    ↓
Return JSON Response
```

#### POST /update Flow
```
Client Request
    ↓
FastAPI Router (routes.py)
    ↓
Auth Dependency (auth.py) - Optional API key check
    ↓
Model Validation (models.py) - Validate request body
    ↓
Capture Previous State (state.py)
    ↓
Update State (state.py)
    ↓
Log to Database (database.py) - Persist change
    ↓
Return Updated State
```

#### GET /logs Flow
```
Client Request
    ↓
FastAPI Router (routes.py)
    ↓
Query Parameter Validation (page, limit)
    ↓
Database Query (database.py) - Paginated retrieval
    ↓
Format Logs (JSON parsing)
    ↓
Return Paginated Response
```

### Data Flow

**State Management:**
- **In-Memory**: `state.py` maintains `counter` and `message` in process memory
- **Persistence**: All state changes are logged to SQLite database
- **Lifecycle**: State resets on container restart, but logs persist

**Database Schema:**
```sql
logs (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    old_value TEXT,  -- JSON string
    new_value TEXT   -- JSON string
)
```

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
5. **Git** - For version control and GitHub integration

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

### GitHub Requirements

1. **GitHub Account** - With a repository containing your application code
2. **GitHub Personal Access Token** - For authentication (create at https://github.com/settings/tokens)
3. **Repository Structure** - Your GitHub repo must contain:
   - `app/` directory with all application files
   - `requirements.txt`
   - `Dockerfile`

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

This project uses **GitHub** to store and deploy the application code. The EC2 instance will automatically clone your repository and deploy it.

### Prerequisites

1. **GitHub Repository**: Your code must be pushed to a GitHub repository
2. **GitHub Personal Access Token**: Required for authentication (even for public repos, it helps avoid rate limits)

### Step 1: Create GitHub Personal Access Token

1. Go to [GitHub Settings > Developer settings > Personal access tokens > Tokens (classic)](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Give it a name (e.g., "Terraform-Python-API")
4. Select scopes: At minimum, select `repo` (for private repos) or just leave it for public repos
5. Click "Generate token"
6. **Copy the token immediately** (you won't see it again!)

### Step 2: Configure Environment Variables

Create a `.env` file in the project root:

```bash
# In the project root directory
cp .env.example .env
```

Edit `.env` and set your GitHub credentials. See `.env.example` for a template:

**Required:**
- `GITHUB_USERNAME` - Your GitHub username
- `GITHUB_REPO_NAME` - Your repository name
- `GITHUB_TOKEN` - Your GitHub personal access token

**Optional:**
- `API_KEY` - API key for `POST /update` endpoint authentication (leave empty to disable)

**Important:** The `.env` file is already in `.gitignore` and will not be committed to version control

### Step 3: Configure AWS Credentials

You can either use `aws configure` or add AWS credentials to your `.env` file:

**Option A: Using aws configure (recommended)**
```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `us-east-1`)
- Default output format (e.g., `json`)

**Option B: Add to .env file**
```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=us-east-1
```

### Step 4: Push Your Code to GitHub

Make sure your code is pushed to GitHub:

```bash
# If you haven't already, initialize git and push
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR_USERNAME/Terraform-Python-API.git
git push -u origin main
```

**Required files in your GitHub repository:**
- `app/` directory with all application files
- `requirements.txt`
- `Dockerfile`

### Step 5: Deploy to AWS

**Option A: Use deploy script (recommended)**
```bash
cd terraform
./deploy.sh
```

The script will automatically:
- Load variables from `.env` file
- Construct the GitHub repository URL: `https://github.com/{GITHUB_USERNAME}/{GITHUB_REPO_NAME}.git`
- Detect your public IP address
- Pass API_KEY to Terraform (if set in `.env`)
- Initialize Terraform
- Deploy the infrastructure

**Note:** If `API_KEY` is set in your `.env` file, it will be automatically passed to the EC2 instance and the Docker container will run with authentication enabled.

**Option B: Manual deployment**
```bash
cd terraform
MY_IP=$(curl -s https://checkip.amazonaws.com)
terraform init
terraform apply \
  -var="my_ip=$MY_IP" \
  -var="github_repo=https://github.com/YOUR_USERNAME/Terraform-Python-API.git" \
  -var="github_token=YOUR_TOKEN" \
  -var="api_key=YOUR_API_KEY"  # Optional: omit to disable authentication
```
```

### What Happens During Deployment

1. **Terraform creates:**
   - EC2 instance (Ubuntu 22.04 LTS, t3.micro)
   - Security group (allows port 5000 from your IP only)

2. **On the EC2 instance, the user_data script:**
   - Updates system packages
   - Installs Docker and Git
   - Starts Docker service
   - Clones your GitHub repository using the token
   - Builds the Docker image from the cloned code
   - Runs the application container on port 5000

3. **Terraform outputs:**
   - Public IP address of the EC2 instance

**Note:** Wait 2-3 minutes after deployment for the instance to boot and the application to start.

### Step 6: Test the Deployed API

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

The script will automatically load variables from `.env` file (or use placeholders if not found).

**Option B: Manual teardown**
```bash
cd terraform
MY_IP=$(curl -s https://checkip.amazonaws.com)
terraform destroy \
  -var="my_ip=$MY_IP" \
  -var="github_repo=https://github.com/YOUR_USERNAME/Terraform-Python-API.git" \
  -var="github_token=YOUR_TOKEN"
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

### Implementing API Key in Terraform

**Enable Authentication:**
- Add `API_KEY=your-secret-api-key-123` to your `.env` file
- Deploy using `./deploy.sh` - the API key will be automatically passed to the container
- The `POST /update` endpoint will require an `X-API-KEY` header with the matching value

**Disable Authentication:**
- Remove the `API_KEY` line from `.env`, or set it to empty: `API_KEY=`
- Deploy again - authentication will be disabled and `POST /update` will work without API key

**Note:** The API key is securely passed from `.env` → Terraform → EC2 user_data → Docker container. Never commit your `.env` file to version control.

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
