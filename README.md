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
| Compute        | AWS EC2 (t2.micro) | Host the Docker container                  |

## API Endpoints

### GET /status
Returns the current state and metadata (uptime, timestamp).

### POST /update
Updates the shared state (counter and/or message). Requires optional API key authentication.

### GET /logs
Returns paginated update history with query parameters:
- `page` (default: 1)
- `limit` (default: 10)

## Project Structure

```
.
├── app.py                 # FastAPI application entry point
├── models.py              # Pydantic models for validation
├── routes.py              # API endpoints and routes
├── state.py               # Shared state management
├── database.py            # SQLite database operations
├── requirements.txt       # Python dependencies
├── Dockerfile             # Multi-stage Docker build
├── terraform/             # Terraform configuration
│   ├── provider.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── user_data.sh
└── README.md              # This file
```

## Security

- **Network Security**: EC2 Security Group restricts inbound traffic to port 5000 from the Terraform runner's IP only
- **API Security**: Optional API key authentication via `X-API-KEY` header for `POST /update`

## Prerequisites

- Python 3.9+
- Docker
- Terraform
- AWS CLI configured with appropriate credentials
- AWS account with permissions to create EC2 instances and Security Groups

## Setup and Deployment

*Details will be added as implementation progresses.*

## Teardown

To destroy all infrastructure:
```bash
cd terraform
terraform destroy
```

## Design Document

See `design_review.md` for complete design specifications and implementation plan.

