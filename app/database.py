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

