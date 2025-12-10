from typing import List, Optional, Any
from pydantic import BaseModel, Field


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


class CaseLog(BaseModel):
    case_id: str
    image_id: Optional[str] = None
    blur_score: Optional[float] = None
    predictions: List[Prediction] = Field(default_factory=list)
    device: Optional[str] = None
    notes: Optional[str] = None
    status: str = "predicted"


class RejectCase(BaseModel):
    case_id: str
    image_id: Optional[str] = None
    reason: Optional[str] = None
    notes: Optional[str] = None

