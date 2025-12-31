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

