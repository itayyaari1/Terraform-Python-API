"""
Pydantic models for request and response validation.
"""

from pydantic import BaseModel, model_validator, Field
from typing import Optional, List
from datetime import datetime


# Request Models

class UpdateRequest(BaseModel):
    """Request model for updating shared state."""
    counter: Optional[int] = Field(None, description="Counter value to set")
    message: Optional[str] = Field(None, description="Message value to set")

    @model_validator(mode='after')
    def validate_at_least_one_field(self):
        """Ensure at least one field is provided."""
        if self.counter is None and self.message is None:
            raise ValueError("At least one field (counter or message) must be provided")
        return self


# Response Models

class StateModel(BaseModel):
    """State model containing counter and message."""
    counter: int = Field(..., description="Current counter value")
    message: str = Field(..., description="Current message value")


class StatusResponse(BaseModel):
    """Response model for GET /status endpoint."""
    state: StateModel = Field(..., description="Current application state")
    timestamp: str = Field(..., description="Current UTC timestamp in ISO format")
    uptime_seconds: int = Field(..., description="Seconds since application startup")


class UpdateResponse(BaseModel):
    """Response model for POST /update endpoint."""
    state: StateModel = Field(..., description="Updated application state")


class LogEntry(BaseModel):
    """Model for a single log entry."""
    id: int = Field(..., description="Log entry ID")
    timestamp: str = Field(..., description="Timestamp of the state change in ISO format")
    old_value: StateModel = Field(..., description="Previous state before the change")
    new_value: StateModel = Field(..., description="New state after the change")


class LogsResponse(BaseModel):
    """Response model for GET /logs endpoint."""
    logs: List[LogEntry] = Field(..., description="List of log entries")
    page: int = Field(..., ge=1, description="Current page number (1-indexed)")
    limit: int = Field(..., ge=1, le=100, description="Number of records per page")
    total: int = Field(..., ge=0, description="Total number of log entries")

