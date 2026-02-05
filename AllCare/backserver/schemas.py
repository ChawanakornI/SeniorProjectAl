from typing import List, Optional, Any
from enum import Enum
from pydantic import BaseModel, Field


class UserRole(str, Enum):
    """User role enumeration for access control."""
    GP = "gp"
    DOCTOR = "doctor"
    ADMIN = "admin"


class User(BaseModel):
    """User model matching structure."""
    user_id: str  # ex. "user001"
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
    isLabeled: Optional[bool] = False # this is for checking whether image have been labeled or not [ labeled mean annotated or changed by user in annotate screen]
    selected_prediction_index: Optional[int] = None  # Index of image selected for prediction


class CaseIdRelease(BaseModel):
    case_id: str


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
    selected_prediction_index: Optional[int] = None  # Index of image selected for prediction


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
    selected_prediction_index: Optional[int] = None  # Index of image selected for prediction


class LabelSubmission(BaseModel):
    correct_label: str
    notes: Optional[str] = None


# (bridge-frontend-backend): Add AnnotationSubmission schema
# This schema validates annotation data from the Flutter AnnotateScreen.
# It includes the corrected label, stroke/box coordinates, and metadata.
#
class AnnotationSubmission(BaseModel):
    """Submission of manual annotations from the AnnotateScreen."""
    image_index: int
    correct_label: str
    annotations: Optional[dict] = None  # Contains 'strokes' and 'boxes'
    case_user_id: Optional[str] = None
    notes: Optional[str] = None
    annotated_at: Optional[str] = None


# Authentication schemas
class LoginRequest(BaseModel):
    """Request body for login endpoint."""
    username: str
    password: str


class UserInfo(BaseModel):
    """User information returned after login."""
    user_id: str
    first_name: str
    last_name: str
    role: str


class TokenResponse(BaseModel):
    """Response from login endpoint."""
    access_token: str
    token_type: str = "bearer"
    user: UserInfo


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


# =============================================================================
# Active Learning Admin Schemas
# =============================================================================

class TrainingConfigRequest(BaseModel):
    """Request body for updating training configuration."""
    epochs: Optional[int] = Field(None, ge=1, le=100)
    batch_size: Optional[int] = Field(None, ge=1, le=128)
    learning_rate: Optional[float] = Field(None, ge=1e-6, le=1.0)
    optimizer: Optional[str] = Field(None, pattern="^(Adam|SGD|AdamW|RMSprop)$")
    dropout: Optional[float] = Field(None, ge=0.0, le=0.9)
    augmentation_applied: Optional[bool] = None


class ModelPromoteRequest(BaseModel):
    """Request body for manual model promotion."""
    reason: Optional[str] = "Manual promotion"


class ModelRollbackRequest(BaseModel):
    """Request body for model rollback."""
    to_version: Optional[str] = None  # If None, rollback to most recent archived
    reason: Optional[str] = "Manual rollback"


class RetrainTriggerRequest(BaseModel):
    """Request body for manually triggering retraining."""
    architecture: Optional[str] = None  # Override architecture (efficientnet_v2_m or resnet50)
    force: bool = False  # Force even if below threshold
