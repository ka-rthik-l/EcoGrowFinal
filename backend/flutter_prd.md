# Flutter Integration PRD — Eco_Grow Backend

## Base URL

```
http://<SERVER_IP>:8000
```

- Android emulator: `http://10.0.2.2:8000`
- Physical device: use your machine's local network IP

## Required Flutter Packages

- `dio` — HTTP client
- `flutter_secure_storage` — persist JWT token securely

---

## API Endpoints

### Authentication

| Endpoint | Method | Content-Type | Description |
|---|---|---|---|
| `/auth/register` | POST | `application/json` | Register a new user |
| `/auth/jwt/login` | POST | `application/x-www-form-urlencoded` | Login, returns JWT token |

**Register** — send `{ "email": "...", "password": "..." }` as JSON.

**Login** — send `username=<email>&password=<pass>` as **form-encoded** (not JSON). Returns `{ "access_token": "...", "token_type": "bearer" }`.

> ⚠️ Login uses `username` field (not `email`) — this is a fastapi-users convention.

---

### Protected Data Endpoints (require `Authorization: Bearer <token>` header)

| Endpoint | Method | Query Params | Flutter Page | Description |
|---|---|---|---|---|
| `/api/v1/dashboard` | GET | — | `dashboard_page.dart` | Latest sensor readings |
| `/api/v1/analysis` | GET | — | `analysis_page.dart` | Soil health score & organic report |
| `/api/v1/trends` | GET | `range` (e.g. `week`) | `trends_page.dart` | Historical data for charts |
| `/api/v1/alerts` | GET | — | `alerts_page.dart` | List of active alerts |

---

## Response Schemas

### `/api/v1/dashboard`
| Field | Type | Description |
|---|---|---|
| temperature | float | Temperature reading |
| humidity | float | Humidity percentage |
| sunlight | float | Sunlight level |
| ph_level | float | Soil pH |
| ec_value | float | Electrical conductivity |
| timestamp | string (ISO) | Reading timestamp |

### `/api/v1/analysis`
| Field | Type | Description |
|---|---|---|
| healthScore | int | Soil health (0–100) |
| isOrganic | bool | Organic confidence |
| metrics | Map<string, string> | Per-metric statuses (e.g. `{"ph": "Optimal"}`) |

### `/api/v1/trends?range=<value>`
| Field | Type | Description |
|---|---|---|
| nitrogen | List\<double\> | Historical nitrogen readings |
| ec | List\<double\> | Historical EC readings |

### `/api/v1/alerts`
Array of objects:

| Field | Type | Description |
|---|---|---|
| title | string | Alert title |
| details | string | Alert description |
| level | string | `"Critical"`, `"Warning"`, or `"Info"` |
| timestamp | string (ISO) | Alert timestamp |
| is_active | bool | Whether alert is currently active |

---

## Integration Steps

1. Add `dio` and `flutter_secure_storage` to `pubspec.yaml`
2. Create an `ApiService` class with a Dio instance pointed at the base URL
3. Add a Dio interceptor that reads the JWT token from secure storage and attaches it as `Authorization: Bearer <token>` on every request
4. **`registration_page.dart`** → Replace mock `_register()` with `POST /auth/register`
5. **`login_page.dart`** → Replace mock login with `POST /auth/jwt/login`, save the returned `access_token` to secure storage
6. **`dashboard_page.dart`** → Replace `_simulateLoad()` with `GET /api/v1/dashboard`, map response fields to UI state
7. **`analysis_page.dart`** → Replace `_simulateLoad()` with `GET /api/v1/analysis`, map `healthScore`, `isOrganic`, `metrics`
8. **`trends_page.dart`** → Replace `_simulateLoad()` with `GET /api/v1/trends?range=<selectedRange>`, feed `nitrogen` and `ec` arrays to charts
9. **`alerts_page.dart`** → Replace `_simulateLoad()` with `GET /api/v1/alerts`, populate alert list from response
10. Call `ApiService.init()` in `main.dart` before `runApp()`

---

## Key Notes

- **Login is form-encoded**, not JSON — use `application/x-www-form-urlencoded`
- **All `/api/v1/*` endpoints require JWT** — requests without a valid token get `401 Unauthorized`
- **Store token in secure storage** so users stay logged in across app restarts
- **Swagger docs** available at `http://<SERVER_IP>:8000/docs` for interactive testing
