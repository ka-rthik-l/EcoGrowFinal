from beanie import PydanticObjectId
from fastapi_users import schemas
from pydantic import BaseModel
from typing import List, Dict


# --- User Schemas (Required by fastapi-users) ---


class UserRead(schemas.BaseUser[PydanticObjectId]):
    pass


class UserCreate(schemas.BaseUserCreate):
    pass


class UserUpdate(schemas.BaseUserUpdate):
    pass


# --- Custom Response Schemas ---


class TrendsResponse(BaseModel):
    nitrogen: List[float]
    phosphorus: List[float]
    potassium: List[float]
    moisture: List[float]
    timestamps: List[str]


class AnalysisResponse(BaseModel):
    healthScore: int
    isOrganic: bool
    label: str  # "organic_manure", "inorganic", "control", "depleted"
    interpretation: str
    metrics: Dict[str, str]

class SensorReadingCreate(BaseModel):
    nitrogen: float
    phosphorus: float
    potassium: float
    moisture: float
