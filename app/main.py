"""
FastAPI application with shared state management.
Main entry point that initializes the application and registers routes.
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from app.routes import router
from app.database import init_database

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

