from contextlib import asynccontextmanager
import os

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie

from app.db import User, SensorReading, Alert
from app.users import auth_backend, fastapi_users
from app.schemas import UserRead, UserCreate
from app.routes import router as data_router

load_dotenv()

MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Connect to MongoDB
    client = AsyncIOMotorClient(MONGODB_URI)
    await init_beanie(
        database=client.eco_grow_db,
        document_models=[User, SensorReading, Alert],
    )
    yield
    client.close()


app = FastAPI(lifespan=lifespan, title="Eco Grow API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,  # JWT is sent via header, not cookies
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Register Auth Routes (fastapi-users) ---
app.include_router(
    fastapi_users.get_auth_router(auth_backend),
    prefix="/auth/jwt",
    tags=["Auth"],
)
app.include_router(
    fastapi_users.get_register_router(UserRead, UserCreate),
    prefix="/auth",
    tags=["Auth"],
)

# --- Register Data Routes ---
app.include_router(data_router)

if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
