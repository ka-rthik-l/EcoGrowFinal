import asyncio
import os
import random
from datetime import datetime, timedelta

from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie

from app.db import User, SensorReading, Alert
from app.users import get_user_manager, auth_backend

# Increase random variance
load_dotenv()
MONGODB_URI = os.getenv("MONGODB_URI")


async def seed():
    client = AsyncIOMotorClient(MONGODB_URI)
    await init_beanie(
        database=client.eco_grow_db,
        document_models=[User, SensorReading, Alert],
    )

    TARGET_EMAIL = "farhan@gm.gov"
    TARGET_PASSWORD = "123456"
    user = await User.find_one(User.email == TARGET_EMAIL)

    from fastapi_users.password import PasswordHelper
    password_helper = PasswordHelper()
    hashed_password = password_helper.hash(TARGET_PASSWORD)

    if not user:
        user = User(
            email=TARGET_EMAIL,
            hashed_password=hashed_password,
            is_active=True,
            is_superuser=False,
            is_verified=False
        )
        await user.insert()
        print(f"Created user: {TARGET_EMAIL} with password: {TARGET_PASSWORD}")
    else:
        # Update password to ensure it matches
        user.hashed_password = hashed_password
        await user.save()
        print(f"Updated user {TARGET_EMAIL} password to: {TARGET_PASSWORD}")

    print("Deleting old readings and alerts for this user...")
    await SensorReading.find(SensorReading.user_id == user.id).delete()
    await Alert.find(Alert.user_id == user.id).delete()

    print("Generating 7 days of mock data (every 10 mins)...")
    now = datetime.utcnow()
    readings = []
    alerts = []

    # 7 days * 24 hours * 6 readings per hour = 1008 readings
    total_points = 7 * 24 * 6
    
    for i in range(total_points):
        timestamp = now - timedelta(minutes=(total_points - i) * 10)
        
        # Base healthy values
        n = random.uniform(40, 60)
        p = random.uniform(30, 45)
        k = random.uniform(45, 65)
        moist = random.uniform(40, 60)

        # Simulation Zones:
        # Day 2: Nitrogen Spike (Chemical Fertilizer)
        if 144 <= i < 200:
            n += random.uniform(30, 50)
            if i == 170:
                alerts.append(Alert(
                    user_id=user.id,
                    title="Nutrient Spike Detected",
                    details="Nitrogen levels surged to critically high levels (90+ mg/kg). Possible inorganic fertilizer runoff.",
                    level="Critical",
                    timestamp=timestamp
                ))

        # Day 4: Soil Dehydration
        if 432 <= i < 500:
            moist -= random.uniform(20, 35)
            if i == 450:
                alerts.append(Alert(
                    user_id=user.id,
                    title="Moisture Depletion",
                    details="Soil moisture fell below 20%. Root zone dehydration detected.",
                    level="Warning",
                    timestamp=timestamp
                ))

        # Day 6: Depleted Soil
        if 720 <= i < 800:
            n -= 30
            p -= 20
            k -= 30
            if i == 750:
                alerts.append(Alert(
                    user_id=user.id,
                    title="Soil Depletion Alert",
                    details="Primary nutrients (NPK) have fallen below growth thresholds. Soil replenishment required.",
                    level="Warning",
                    timestamp=timestamp
                ))

        readings.append(SensorReading(
            user_id=user.id,
            nitrogen=round(n, 1),
            phosphorus=round(p, 1),
            potassium=round(k, 1),
            moisture=round(moist, 1),
            timestamp=timestamp,
        ))

    await SensorReading.insert_many(readings)
    if alerts:
        await Alert.insert_many(alerts)
    print(f"Inserted {len(readings)} readings and {len(alerts)} alerts successfully!")

    client.close()


if __name__ == "__main__":
    asyncio.run(seed())
