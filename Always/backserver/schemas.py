from typing import List, Optional, Any
from enum import Enum
from pydantic import BaseModel, Field


class UserRole(str, Enum):
    """User role enumeration for access control."""
    GP = "gp"
    DOCTOR = "doctor"
    ADMIN = "admin"


class User(BaseModel):
    """User model matching mock_credentials.csv structure."""
    user_id: str  # e.g., "user001"
    name: str
    surname: str
    role: UserRole

    @property
    def full_name(self) -> str:
        return f"{self.name} {self.surname}"


class Prediction(BaseModel):
    label: str
    confidence: float


class CheckImageResponse(BaseModel):
    status: str
    message: str
    blur_score: float
    predictions: List[Prediction] = Field(default_factory=list)
    image_id: Optional[str] = None
    case_id: Optional[str] = None
    user_id: Optional[str] = None
    user_role: Optional[str] = None


class CaseLog(BaseModel):
    case_id: str
    user_id: Optional[str] = None  # Owner of this case
    user_role: Optional[str] = None
    image_id: Optional[str] = None
    blur_score: Optional[float] = None
    predictions: List[Prediction] = Field(default_factory=list)
    device: Optional[str] = None
    notes: Optional[str] = None
    status: str = "pending"
    # Optional patient/case metadata
    gender: Optional[str] = None
    age: Optional[str] = None
    location: Optional[str] = None
    symptoms: List[str] = Field(default_factory=list)
    image_paths: List[str] = Field(default_factory=list)  # Paths to captured images
    created_at: Optional[str] = None  # ISO format timestamp


class CaseUpdate(BaseModel):
    user_id: Optional[str] = None
    user_role: Optional[str] = None
    image_id: Optional[str] = None
    blur_score: Optional[float] = None
    predictions: Optional[List[Prediction]] = None
    device: Optional[str] = None
    notes: Optional[str] = None
    status: Optional[str] = None
    gender: Optional[str] = None
    age: Optional[str] = None
    location: Optional[str] = None
    symptoms: Optional[List[str]] = None
    image_paths: Optional[List[str]] = None
    created_at: Optional[str] = None


class RejectCase(BaseModel):
    case_id: str
    user_id: Optional[str] = None  # Owner of this case
    user_role: Optional[str] = None
    image_id: Optional[str] = None
    reason: Optional[str] = None
    notes: Optional[str] = None
    # Added fields to persist context for rejected cases
    predictions: List[Prediction] = Field(default_factory=list)
    gender: Optional[str] = None
    age: Optional[str] = None
    location: Optional[str] = None
    symptoms: List[str] = Field(default_factory=list)
    image_paths: List[str] = Field(default_factory=list)
    created_at: Optional[str] = None


# Role-based access permissions
ROLE_PERMISSIONS = {
    UserRole.GP: {
        "can_create_case": True,
        "can_view_own_cases": True,
        "can_view_all_cases": False,
        "can_make_final_decision": False,
        "can_give_image_decision": True,
        "can_view_all_users": False,
    },
    UserRole.DOCTOR: {
        "can_create_case": True,
        "can_view_own_cases": True,
        "can_view_all_cases": True,  # Doctors can see all cases for review
        "can_make_final_decision": True,
        "can_give_image_decision": True,
        "can_view_all_users": True,
    },
    UserRole.ADMIN: {
        "can_create_case": True,
        "can_view_own_cases": True,
        "can_view_all_cases": True,
        "can_make_final_decision": True,
        "can_give_image_decision": True,
        "can_view_all_users": True,
    },
}


def get_user_permissions(role: UserRole) -> dict:
    """Get permissions dict for a given role."""
    return ROLE_PERMISSIONS.get(role, {})
