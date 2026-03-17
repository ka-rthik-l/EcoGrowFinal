# Eco_Grow Backend — Product Requirements Document

## Overview

FastAPI + Beanie (MongoDB) backend for the Eco_Grow Flutter mobile app. Provides JWT authentication and RESTful APIs for real-time sensor dashboard, soil analysis, historical trends, and alerts.

## Tech Stack

- **Framework:** FastAPI
- **ODM:** Beanie (async MongoDB via Motor)
- **Auth:** fastapi-users with JWT bearer tokens
- **Database:** MongoDB
- **Package Manager:** uv (Astral)

## Project Structure

```text
eco_test2/
├── main.py                 # Entry point, lifespan (DB init), router registration
├── pyproject.toml           # Dependencies managed via uv
├── app/
│   ├── __init__.py
│   ├── db.py               # Beanie document models (User, SensorReading, Alert)
│   ├── schemas.py          # Pydantic request/response schemas
│   ├── users.py            # fastapi-users JWT auth configuration
│   └── routes.py           # Custom API endpoints
```

## Data Models

### User
Extends `BeanieBaseUser` (fastapi-users). Handles email, hashed_password, is_active, is_superuser, is_verified automatically.

### SensorReading
| Field | Type | Description |
|---|---|---|
| user_id | ObjectId | Owner reference |
| temperature | float | Temperature reading |
| humidity | float | Humidity percentage |
| sunlight | float | Sunlight level |
| ph_level | float | Soil pH |
| ec_value | float | Electrical conductivity |
| timestamp | datetime | Auto-set to creation time |

### Alert
| Field | Type | Description |
|---|---|---|
| user_id | ObjectId | Owner reference |
| title | str | Alert title |
| details | str | Alert description |
| level | str | "Critical", "Warning", or "Info" |
| timestamp | datetime | Auto-set to creation time |
| is_active | bool | Whether alert is currently active |

## API Endpoints

### Authentication (fastapi-users built-in)

| Endpoint | Method | Flutter Page | Description |
|---|---|---|---|
| `/auth/register` | POST | `registration_page.dart` | Register with email + password |
| `/auth/jwt/login` | POST | `login_page.dart` | Login, returns JWT access token |

### Data Endpoints (JWT-protected, prefix `/api/v1`)

| Endpoint | Method | Flutter Page | Response |
|---|---|---|---|
| `/api/v1/dashboard` | GET | `dashboard_page.dart` | Latest SensorReading (temp, humidity, sunlight, pH, EC) |
| `/api/v1/analysis` | GET | `analysis_page.dart` | `{ healthScore, isOrganic, metrics }` |
| `/api/v1/trends?range=` | GET | `trends_page.dart` | `{ nitrogen: [...], ec: [...] }` |
| `/api/v1/alerts` | GET | `alerts_page.dart` | List of active Alert objects |

## Dependencies

```
fastapi
uvicorn[standard]
motor
beanie
fastapi-users[beanie]
pydantic[email]
```