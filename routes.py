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

