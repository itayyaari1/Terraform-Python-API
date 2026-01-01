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

## 3. Application Architecture

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
| **Models** | `app/models.py` | Pydantic models for request and response validation |
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
Return StatusResponse (Pydantic model)
```

#### POST /update Flow
```
Client Request
    ↓
FastAPI Router (routes.py)
    ↓
Auth Dependency (auth.py) - Optional API key check
    ↓
Model Validation (models.py) - Validate UpdateRequest
    ↓
Capture Previous State (state.py)
    ↓
Update State (state.py)
    ↓
Log to Database (database.py) - Persist change
    ↓
Return UpdateResponse (Pydantic model)
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
Convert to Pydantic Models (LogEntry, LogsResponse)
    ↓
Return LogsResponse (Pydantic model)
```

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

Pydantic models are used for both request and response validation, ensuring type safety and automatic API documentation.

**Request Models:**
```python
class UpdateRequest(BaseModel):
    counter: Optional[int] = Field(None, description="Counter value to set")
    message: Optional[str] = Field(None, description="Message value to set")
```

**Response Models:**
```python
class StateModel(BaseModel):
    counter: int
    message: str

class StatusResponse(BaseModel):
    state: StateModel
    timestamp: str
    uptime_seconds: int

class UpdateResponse(BaseModel):
    state: StateModel

class LogEntry(BaseModel):
    id: int
    timestamp: str
    old_value: StateModel
    new_value: StateModel

class LogsResponse(BaseModel):
    logs: List[LogEntry]
    page: int
    limit: int
    total: int
```

Validation rules:

* At least one field must be provided in `UpdateRequest`
* `counter` must be an integer
* `message` must be a string
* All responses are validated using Pydantic models
* FastAPI automatically generates OpenAPI schema from models

Invalid input results in an HTTP 400 response with detailed error messages.

---

### 4.3 API Endpoints

#### GET /status

Returns the current state and metadata.

**Response Model:** `StatusResponse`

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

**Request Model:** `UpdateRequest`  
**Response Model:** `UpdateResponse`

Flow:

1. (Optional) Validate API key from request header
2. Validate request payload using `UpdateRequest` model
3. Capture previous state
4. Update shared state
5. Persist change in logs database
6. Return updated state using `UpdateResponse` model

Error handling:

* 400 – validation error (Pydantic validation)
* 401 – invalid or missing API key (if enabled)

---

#### GET /logs

**Response Model:** `LogsResponse`

* Returns paginated update history
* Query parameters:
  * `page` (default: 1, minimum: 1)
  * `limit` (default: 10, minimum: 1, maximum: 100)

**Response Structure:**
```json
{
  "logs": [
    {
      "id": 1,
      "timestamp": "2025-01-01T12:00:00Z",
      "old_value": {"counter": 0, "message": "initial"},
      "new_value": {"counter": 1, "message": "updated"}
    }
  ],
  "page": 1,
  "limit": 10,
  "total": 1
}
```

Pagination logic:

```sql
SELECT * FROM logs
ORDER BY timestamp DESC
LIMIT ? OFFSET ?
```

All log entries are returned as `LogEntry` Pydantic models with nested `StateModel` for old_value and new_value.

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
* Log entries are converted to `LogEntry` Pydantic models when retrieved

### Data Flow

**State Management:**
- **In-Memory**: `state.py` maintains `counter` and `message` in process memory
- **Persistence**: All state changes are logged to SQLite database
- **Lifecycle**: State resets on container restart, but logs persist

**Request/Response Flow:**
- All requests are validated using Pydantic request models
- All responses are serialized using Pydantic response models
- FastAPI automatically generates OpenAPI schema from models
- Type safety is enforced at runtime

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
uvicorn app.main:app --host 0.0.0.0 --port 5000
```

* Application structure: Uses `app/` package with `main.py` as entry point

This approach minimizes image size and attack surface.

---

## 8. Terraform Design

### File Structure

```
terraform/
├── provider.tf          # AWS provider configuration
├── main.tf               # EC2 instance and security group
├── variables.tf          # Input variables (my_ip, github_repo, github_token)
├── outputs.tf            # Output values (public_ip, instance_id)
├── user_data.sh          # Bootstrap script (clones from GitHub, builds Docker)
├── deploy.sh             # Deployment script (reads from .env)
└── teardown.sh           # Teardown script
```

### Configuration

* **Environment Variables**: GitHub credentials stored in `.env` file (not committed to version control)
* **GitHub Integration**: Application code is cloned from GitHub repository during EC2 bootstrap
* **Token Authentication**: GitHub token used for repository access (supports both public and private repos)
* **Deployment Script**: Automatically reads `.env` file and constructs GitHub URL

---

### EC2 Provisioning

* AMI: Ubuntu 22.04 LTS (dynamically fetched via `data "aws_ami"` block)
* Instance type: t3.micro (free tier eligible)
* Region: us-east-1 (hardcoded)
* user_data script performs:
  * System package updates (apt-get)
  * Docker and Git installation
  * Docker daemon startup
  * Clone application code from GitHub (using token authentication)
  * Docker image build from cloned code
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

* Create modular package structure:
  * `app/__init__.py` - Package initialization
  * `app/main.py` - Main entry point (FastAPI app)
  * `app/state.py` - Shared state management
  * `app/routes.py` - API endpoints
  * `app/models.py` - Pydantic models (requests and responses)
  * `app/database.py` - SQLite operations
  * `app/auth.py` - API key authentication
* Implement shared state
* Implement `GET /status` with `StatusResponse` model

### Step 3 – Update Endpoint and Validation

* Add Pydantic request model (`UpdateRequest`) in `models.py`
* Add Pydantic response model (`UpdateResponse`) in `models.py`
* Implement `POST /update` in `routes.py` with response_model
* Handle validation errors

### Step 4 – Logging Layer

* Initialize SQLite database in `database.py`
* Create logs table
* Persist updates
* Add Pydantic response models (`LogEntry`, `LogsResponse`) in `models.py`
* Implement `GET /logs` with pagination and Pydantic response models

### Step 5 – Optional API Key Authentication

* Create `auth.py` with dependency function
* Read API key from environment
* Apply to `POST /update` endpoint

### Step 6 – Dockerization

* Write multi-stage Dockerfile
* Build and test locally

### Step 7 – Terraform Base Infrastructure

* Configure AWS provider
* Create EC2 and Security Group
* Validate provisioning

### Step 8 – Application Deployment on EC2

* Configure GitHub repository and token in `.env` file
* Update user_data script to clone from GitHub
* Integrate Docker build/run in user_data
* Verify endpoints via public IP

### Step 9 – Teardown

* Run `terraform destroy`
* Verify all resources are deleted

---

## 10. Design Decisions and Trade-offs

* **FastAPI vs Flask**: FastAPI provides built-in validation, typing, and OpenAPI support
* **Pydantic Models for All Requests/Responses**: Ensures type safety, automatic validation, and better API documentation
* **Modular Package Structure**: Using `app/` package instead of flat structure improves organization and maintainability
* **GitHub for Code Deployment**: Cloning from GitHub instead of hardcoding files makes updates easier and follows best practices
* **SQLite vs external DB**: SQLite is sufficient and simpler for the task scope
* **In-memory state**: Acceptable trade-off for simplicity (state resets on restart, but logs persist)
* **Terraform user_data vs configuration management tools**: user_data keeps automation minimal and self-contained
* **Ubuntu vs Amazon Linux 2**: Ubuntu provides better package availability and broader community support

---

## 11. Interview Readiness

The design supports clear discussion around:

* Architecture and component responsibilities
* Security considerations
* Automation strategy
* Trade-offs and simplifications
* Testing and verification steps

This document can be used as both an implementation guide and an interview reference.
