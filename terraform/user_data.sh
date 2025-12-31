#!/bin/bash

# Update system packages (Ubuntu uses apt)
apt-get update -y

# Install Docker
apt-get install -y docker.io

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

# Create requirements.txt
cat > requirements.txt << 'EOF'
fastapi>=0.115.0
uvicorn[standard]>=0.32.0
pydantic>=2.10.0
EOF

# Create app.py
cat > app.py << 'EOF'
"""
FastAPI application with shared state management.
Main entry point that initializes the application and registers routes.
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from routes import router
from database import init_database

# Initialize FastAPI app
app = FastAPI(title="Python API", version="1.0.0")

# Initialize database on startup
@app.on_event("startup")
async def startup_event():
    """Initialize database on application startup."""
    init_database()

# Register routes
app.include_router(router)


@app.exception_handler(ValidationError)
async def validation_exception_handler(request: Request, exc: ValidationError):
    """Convert Pydantic validation errors to HTTP 400."""
    return JSONResponse(
        status_code=400,
        content={"detail": str(exc)}
    )
EOF

# Create models.py
cat > models.py << 'EOF'
"""
Pydantic models for request validation.
"""

from pydantic import BaseModel, model_validator
from typing import Optional


class UpdateRequest(BaseModel):
    """Request model for updating shared state."""
    counter: Optional[int] = None
    message: Optional[str] = None

    @model_validator(mode='after')
    def validate_at_least_one_field(self):
        """Ensure at least one field is provided."""
        if self.counter is None and self.message is None:
            raise ValueError("At least one field (counter or message) must be provided")
        return self
EOF

# Create routes.py
cat > routes.py << 'ROUTES_EOF'
"""
API routes and endpoints.
"""

from datetime import datetime, timezone
from fastapi import APIRouter, Query, Depends
from models import UpdateRequest
from state import state, start_timestamp
from database import log_update, get_logs
from auth import verify_api_key

# Create router
router = APIRouter()


@router.get("/status")
async def get_status():
    """
    Returns the current state and metadata.
    
    Response includes:
    - state: Current counter and message values
    - timestamp: Current UTC timestamp
    - uptime_seconds: Seconds since application startup
    """
    current_timestamp = datetime.now(timezone.utc)
    uptime_seconds = int((current_timestamp - start_timestamp).total_seconds())
    
    return {
        "state": {
            "counter": state["counter"],
            "message": state["message"]
        },
        "timestamp": current_timestamp.isoformat(),
        "uptime_seconds": uptime_seconds
    }


@router.post("/update")
async def update_state(
    request: UpdateRequest,
    api_key_valid: bool = Depends(verify_api_key)
):
    """
    Updates the shared state with new counter and/or message values.
    
    Flow:
    1. (Optional) Validate API key from request header
    2. Validate request payload
    3. Capture previous state
    4. Update shared state
    5. Persist change in logs database
    6. Return updated state
    
    Error handling:
    - 400: validation error
    - 401: invalid or missing API key (if enabled)
    """
    # Capture previous state
    previous_state = {
        "counter": state["counter"],
        "message": state["message"]
    }
    
    # Update shared state with provided values
    if request.counter is not None:
        state["counter"] = request.counter
    if request.message is not None:
        state["message"] = request.message
    
    # Capture new state
    new_state = {
        "counter": state["counter"],
        "message": state["message"]
    }
    
    # Persist change in logs database
    log_update(previous_state, new_state)
    
    # Return updated state
    return {
        "state": {
            "counter": state["counter"],
            "message": state["message"]
        }
    }


@router.get("/logs")
async def get_logs_endpoint(
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    limit: int = Query(10, ge=1, le=100, description="Number of records per page")
):
    """
    Returns paginated update history.
    
    Query parameters:
    - page: Page number (default: 1, minimum: 1)
    - limit: Number of records per page (default: 10, minimum: 1, maximum: 100)
    
    Returns logs ordered by timestamp (most recent first).
    """
    return get_logs(page=page, limit=limit)
ROUTES_EOF

# Create state.py
cat > state.py << 'EOF'
"""
Shared state management for the application.
"""

from datetime import datetime, timezone
from typing import Dict


# Shared state in memory
state: Dict[str, any] = {
    "counter": 0,
    "message": "initial"
}

# Application start timestamp for uptime calculation
start_timestamp: datetime = datetime.now(timezone.utc)
EOF

# Create database.py
cat > database.py << 'DB_EOF'
"""
SQLite database operations for logging.
"""

import sqlite3
import json
from datetime import datetime, timezone
from typing import List, Dict, Optional

# Database file path
DB_FILE = "logs.db"


def init_database():
    """
    Initialize the SQLite database and create the logs table if it doesn't exist.
    """
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            old_value TEXT,
            new_value TEXT
        )
    """)
    
    conn.commit()
    conn.close()


def log_update(old_value: Dict, new_value: Dict):
    """
    Log a state update to the database.
    
    Args:
        old_value: Previous state dictionary
        new_value: New state dictionary
    """
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    timestamp = datetime.now(timezone.utc).isoformat()
    old_value_json = json.dumps(old_value)
    new_value_json = json.dumps(new_value)
    
    cursor.execute("""
        INSERT INTO logs (timestamp, old_value, new_value)
        VALUES (?, ?, ?)
    """, (timestamp, old_value_json, new_value_json))
    
    conn.commit()
    conn.close()


def get_logs(page: int = 1, limit: int = 10) -> Dict:
    """
    Retrieve paginated logs from the database.
    
    Args:
        page: Page number (1-indexed)
        limit: Number of records per page
    
    Returns:
        Dictionary with logs, pagination info, and total count
    """
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    # Calculate offset
    offset = (page - 1) * limit
    
    # Get total count
    cursor.execute("SELECT COUNT(*) FROM logs")
    total = cursor.fetchone()[0]
    
    # Get paginated logs
    cursor.execute("""
        SELECT id, timestamp, old_value, new_value
        FROM logs
        ORDER BY timestamp DESC
        LIMIT ? OFFSET ?
    """, (limit, offset))
    
    rows = cursor.fetchall()
    conn.close()
    
    # Format logs
    logs = []
    for row in rows:
        logs.append({
            "id": row[0],
            "timestamp": row[1],
            "old_value": json.loads(row[2]),
            "new_value": json.loads(row[3])
        })
    
    return {
        "logs": logs,
        "page": page,
        "limit": limit,
        "total": total
    }
DB_EOF

# Create auth.py
cat > auth.py << 'EOF'
"""
API key authentication for protected endpoints.
"""

import os
from fastapi import Header, HTTPException
from typing import Optional


def get_api_key_from_env() -> Optional[str]:
    """
    Get API key from environment variable.
    
    Returns:
        API key string if set, None if not configured (making auth optional)
    """
    return os.getenv("API_KEY")


async def verify_api_key(x_api_key: Optional[str] = Header(None, alias="X-API-KEY")):
    """
    Dependency function to verify API key from request header.
    
    If API_KEY environment variable is set, validates the provided key.
    If API_KEY is not set, authentication is disabled (optional).
    
    Args:
        x_api_key: API key from X-API-KEY header
    
    Raises:
        HTTPException: 401 if API key is required but missing or invalid
    """
    expected_api_key = get_api_key_from_env()
    
    # If API key is not configured in environment, skip authentication
    if expected_api_key is None:
        return True
    
    # If API key is configured, validate the provided key
    if x_api_key is None:
        raise HTTPException(
            status_code=401,
            detail="API key is required. Please provide X-API-KEY header."
        )
    
    if x_api_key != expected_api_key:
        raise HTTPException(
            status_code=401,
            detail="Invalid API key."
        )
    
    return True
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
# Multi-stage Dockerfile for optimized image size

# Stage 1: Builder stage
FROM python:3.11-slim as builder

# Set working directory
WORKDIR /app

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime stage
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy only installed packages from builder stage
COPY --from=builder /root/.local /root/.local

# Copy application files
COPY app.py models.py routes.py state.py database.py auth.py ./

# Make sure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH

# Expose port 5000
EXPOSE 5000

# Set entrypoint
ENTRYPOINT ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "5000"]
EOF

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
