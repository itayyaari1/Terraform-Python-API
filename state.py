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

