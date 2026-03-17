from datetime import datetime
from beanie import Document, PydanticObjectId
from pydantic import Field
from fastapi_users_db_beanie import BeanieBaseUser


# --- Models ---


class User(BeanieBaseUser, Document):
    # fastapi-users handles email, hashed_password, is_active, is_superuser, is_verified
    pass


class SensorReading(Document):
    user_id: PydanticObjectId
    nitrogen: float
    phosphorus: float
    potassium: float
    moisture: float
    timestamp: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "sensor_readings"


class Alert(Document):
    user_id: PydanticObjectId
    title: str
    details: str
    level: str  # "Critical", "Warning", "Info"
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    is_active: bool = True

    class Settings:
        name = "alerts"
