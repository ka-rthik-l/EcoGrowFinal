import asyncio
import os
import sys

import httpx

async def test_api():
    base_url = "http://localhost:8000"
    
    # 1. Login to get token
    print("Logging in...")
    async with httpx.AsyncClient() as client:
        # FastAPI users uses form-data for login by default
        login_data = {"username": "farhan@gm.gov", "password": "123456"}
        response = await client.post(f"{base_url}/auth/jwt/login", data=login_data)
        
        if response.status_code != 200:
            print(f"Login failed: {response.status_code} - {response.text}")
            sys.exit(1)
            
        token = response.json()["access_token"]
        print(f"Successfully got token: {token[:10]}...")
        
        headers = {"Authorization": f"Bearer {token}"}
        
        # 2. Test /api/v1/dashboard
        print("\n--- Testing /api/v1/dashboard ---")
        dash_response = await client.get(f"{base_url}/api/v1/dashboard", headers=headers)
        print(f"Status: {dash_response.status_code}")
        print(f"Response: {dash_response.json()}")
        
        # 3. Test /api/v1/trends
        print("\n--- Testing /api/v1/trends ---")
        trends_response = await client.get(f"{base_url}/api/v1/trends?range=7d", headers=headers)
        print(f"Status: {trends_response.status_code}")
        trends_data = trends_response.json()
        print(f"Nitrogen count: {len(trends_data.get('nitrogen', []))}")
        print(f"Phosphorus count: {len(trends_data.get('phosphorus', []))}")
        print(f"Potassium count: {len(trends_data.get('potassium', []))}")
        print(f"Moisture count: {len(trends_data.get('moisture', []))}")
        
        # 4. Test /api/v1/analysis
        print("\n--- Testing /api/v1/analysis ---")
        analysis_response = await client.get(f"{base_url}/api/v1/analysis", headers=headers)
        print(f"Status: {analysis_response.status_code}")
        print(f"Response: {analysis_response.json()}")

if __name__ == "__main__":
    asyncio.run(test_api())
