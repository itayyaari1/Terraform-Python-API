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

