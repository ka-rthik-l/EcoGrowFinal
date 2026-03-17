import asyncio
import time
import httpx
import random
import sys
import argparse

BASE_URL = "http://localhost:8000"
LOGIN_DATA = {"username": "farhan@gm.gov", "password": "123456"}

# Simulation profiles (Start and End values for interpolation)
PROFILES = [
    {
        "name": "control",
        "description": "Healthy Control Soil (Baseline)",
        "N": (128, 133),
        "P": (82, 85),
        "K": (105, 108),
        "M": (48, 46),
        "steps": 60
    },
    {
        "name": "depleted",
        "description": "Depleted Soil (Nutrient-poor)",
        "N": (45, 42),
        "P": (30, 28),
        "K": (41, 38),
        "M": (22, 24),
        "steps": 60
    },
    {
        "name": "organic_manure",
        "description": "Organic Manure (Slow Release)",
        "N": (118, 185),
        "P": (74, 116),
        "K": (95, 162),
        "M": (54, 49),
        "steps": 60
    },
    {
        "name": "inorganic",
        "description": "Inorganic Fertilizer (Chemical Spike)",
        "N": (120, 860),
        "P": (80, 545),
        "K": (100, 700),
        "M": (56, 18),
        "steps": 60
    }
]

async def get_token():
    print(f"Logging in as {LOGIN_DATA['username']}...")
    async with httpx.AsyncClient() as client:
        response = await client.post(f"{BASE_URL}/auth/jwt/login", data=LOGIN_DATA)
        if response.status_code != 200:
            print(f"❌ Login failed: {response.text}")
            sys.exit(1)
        return response.json()["access_token"]

def interpolate(start, end, step, total_steps):
    return start + (end - start) * (step / total_steps)

async def simulate(delay_seconds):
    token = await get_token()
    headers = {"Authorization": f"Bearer {token}"}
    
    total_sent = 0
    async with httpx.AsyncClient(headers=headers, timeout=10) as client:
        for profile in PROFILES:
            print(f"\n🚀 Simulation: {profile['name'].upper()} - {profile['description']}")
            print("-" * 60)
            print(f"Update Interval: {delay_seconds} seconds")
            
            for i in range(profile['steps']):
                # Calculate interpolated values
                n = interpolate(profile['N'][0], profile['N'][1], i, profile['steps'])
                p = interpolate(profile['P'][0], profile['P'][1], i, profile['steps'])
                k = interpolate(profile['K'][0], profile['K'][1], i, profile['steps'])
                m = interpolate(profile['M'][0], profile['M'][1], i, profile['steps'])
                
                # Add a bit of jitter (noise)
                n += random.uniform(-1, 1)
                p += random.uniform(-0.5, 0.5)
                k += random.uniform(-1, 1)
                m += random.uniform(-0.5, 0.5)
                
                payload = {
                    "nitrogen": round(float(n), 2),
                    "phosphorus": round(float(p), 2),
                    "potassium": round(float(k), 2),
                    "moisture": round(float(m), 2)
                }
                
                try:
                    response = await client.post(f"{BASE_URL}/api/v1/sensor-reading", json=payload)
                    if response.status_code == 200:
                        total_sent += 1
                        print(f"[{total_sent:03}] Sent: N={payload['nitrogen']:>6}, P={payload['phosphorus']:>6}, K={payload['potassium']:>6}, M={payload['moisture']:>6} | State: {profile['name']}", end="\r")
                    else:
                        print(f"\n❌ Error: {response.status_code} - {response.text}")
                except Exception as e:
                    print(f"\n❌ Request failed: {e}")
                
                # Wait for the specified interval
                await asyncio.sleep(delay_seconds)
            print(f"\n✅ Finished {profile['name']} sequence.")

    print(f"\n🎉 Simulation Complete! Total readings sent: {total_sent}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Real-time Sensor Simulator")
    parser.add_argument("--delay", type=float, default=120, help="Delay between readings in seconds (default: 120)")
    args = parser.parse_args()

    try:
        asyncio.run(simulate(args.delay))
    except KeyboardInterrupt:
        print("\n👋 Simulation stopped by user.")
