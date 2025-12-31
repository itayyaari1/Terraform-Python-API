"""
FastAPI application with shared state management.
"""

from datetime import datetime, timezone
from fastapi import FastAPI
from typing import Dict

# Initialize FastAPI app
app = FastAPI(title="Python API", version="1.0.0")

# Shared state in memory
state: Dict[str, any] = {
    "counter": 0,
    "message": "initial"
}

# Application start timestamp for uptime calculation
start_timestamp: datetime = datetime.now(timezone.utc)


@app.get("/status")
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

