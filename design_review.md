# Design Review – Python API with Automated Deployment and Teardown

## 1. Overview

This document describes the proposed design, architecture, and step-by-step implementation plan for the **Python API Application with Automated Deployment and Teardown** task.
The goal is to provide a clear, production-oriented design review that can be directly used to guide implementation (e.g., via Cursor) and explained confidently during an interview.

---

## 2. Objectives and Scope

### Objectives

* Build a clean and well-structured Python API using FastAPI
* Containerize the application using Docker with optimized image size
* Fully automate infrastructure provisioning and teardown using Terraform
* Ensure basic security best practices (IP whitelisting, optional API key)
* Provide clear documentation and reproducible setup

### Non-Goals

* High availability or autoscaling
* CI/CD pipelines
* Advanced secret management (e.g., AWS Secrets Manager)

---

## 3. High-Level Architecture

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

### Component Responsibilities

| Component      | Technology         | Responsibility                             |
| -------------- | ------------------ | ------------------------------------------ |
| API            | FastAPI            | Expose REST endpoints, validation, logging |
| Container      | Docker             | Package and run the application            |
| Database       | SQLite             | Persist update logs                        |
| Infrastructure | Terraform          | Provision and destroy AWS resources        |
| Compute        | AWS EC2 (t2.micro) | Host the Docker container                  |

---

## 4. Application Design

### 4.1 Shared State Management

The application maintains a simple shared state in memory:

```python
state = {
    "counter": 0,
    "message": "initial"
}
```

* State is process-local and reset on container restart
* This trade-off is acceptable for the scope of the task

An application start timestamp is stored at startup to calculate uptime.

---

### 4.2 Data Models and Validation

Pydantic models are used for request validation.

```python
class UpdateRequest(BaseModel):
    counter: Optional[int]
    message: Optional[str]
```

Validation rules:

* At least one field must be provided
* `counter` must be an integer
* `message` must be a string

Invalid input results in an HTTP 400 response.

---

### 4.3 API Endpoints

#### GET /status

Returns the current state and metadata.

Response example:

```json
{
  "state": {
    "counter": 1,
    "message": "hello"
  },
  "timestamp": "2025-01-01T12:00:00Z",
  "uptime_seconds": 120
}
```

---

#### POST /update

Flow:

1. (Optional) Validate API key from request header
2. Validate request payload
3. Capture previous state
4. Update shared state
5. Persist change in logs database
6. Return updated state

Error handling:

* 400 – validation error
* 401 – invalid or missing API key (if enabled)

---

#### GET /logs

* Returns paginated update history
* Query parameters:
  * `page` (default: 1)
  * `limit` (default: 10)

Pagination logic:

```sql
SELECT * FROM logs
ORDER BY timestamp DESC
LIMIT ? OFFSET ?
```

---

## 5. Logging and Persistence

### SQLite Database

The application uses SQLite for lightweight persistence.

Schema:

```sql
CREATE TABLE logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT,
    old_value TEXT,
    new_value TEXT
);
```

* `old_value` and `new_value` are stored as JSON strings
* Database is initialized automatically at application startup

---

## 6. Security Design

### Network Security

* EC2 Security Group allows inbound traffic only:
  * TCP port 5000
  * Source IP: the machine running Terraform (`<MY_IP>/32`)

### API Security (Optional)

* Simple API key authentication for `POST /update`
* API key passed via `X-API-KEY` header
* Key stored as environment variable inside the container

---

## 7. Docker Design

### Multi-Stage Build Strategy

Stages:

1. **Builder stage**
   * Install Python dependencies
2. **Runtime stage**
   * Use slim Python image
   * Copy only required artifacts

Container configuration:

* Exposed port: 5000
* Entrypoint:

```bash
uvicorn app:app --host 0.0.0.0 --port 5000
```

This approach minimizes image size and attack surface.

---

## 8. Terraform Design

### File Structure

```
terraform/
├── provider.tf
├── main.tf
├── variables.tf
├── outputs.tf
└── user_data.sh
```

---

### EC2 Provisioning

* AMI: Amazon Linux 2
* Instance type: t2.micro
* user_data script performs:
  * Docker installation
  * Docker daemon startup
  * Application image build
  * Container run

---

### Security Group

Inbound rules:

* Port 5000 / TCP
* Source: Terraform runner IP

Outbound rules:

* Allow all

---

### Outputs

```hcl
output "public_ip" {
  value = aws_instance.api.public_ip
}
```

Used for API verification after deployment.

---

## 9. Step-by-Step Implementation Plan

### Step 1 – Project Skeleton

* Create repository structure
* Initialize README

### Step 2 – Base FastAPI Application

* Create `app.py`
* Implement shared state
* Implement `GET /status`

### Step 3 – Update Endpoint and Validation

* Add Pydantic model
* Implement `POST /update`
* Handle validation errors

### Step 4 – Logging Layer

* Initialize SQLite database
* Create logs table
* Persist updates
* Implement `GET /logs` with pagination

### Step 5 – Optional API Key Authentication

* Add middleware or dependency
* Read API key from environment

### Step 6 – Dockerization

* Write multi-stage Dockerfile
* Build and test locally

### Step 7 – Terraform Base Infrastructure

* Configure AWS provider
* Create EC2 and Security Group
* Validate provisioning

### Step 8 – Application Deployment on EC2

* Integrate Docker build/run in user_data
* Verify endpoints via public IP

### Step 9 – Teardown

* Run `terraform destroy`
* Verify all resources are deleted

---

## 10. Design Decisions and Trade-offs

* **FastAPI vs Flask**: FastAPI provides built-in validation, typing, and OpenAPI support
* **SQLite vs external DB**: SQLite is sufficient and simpler for the task scope
* **In-memory state**: Acceptable trade-off for simplicity
* **Terraform user_data vs configuration management tools**: user_data keeps automation minimal and self-contained

---

## 11. Interview Readiness

The design supports clear discussion around:

* Architecture and component responsibilities
* Security considerations
* Automation strategy
* Trade-offs and simplifications
* Testing and verification steps

This document can be used as both an implementation guide and an interview reference.
