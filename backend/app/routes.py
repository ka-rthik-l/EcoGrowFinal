from fastapi import APIRouter, Depends, HTTPException
from typing import List

from app.db import User, SensorReading, Alert
from app.users import current_active_user
from app.schemas import TrendsResponse, AnalysisResponse, SensorReadingCreate

router = APIRouter(prefix="/api/v1", tags=["Data"])


@router.get("/dashboard", response_model=SensorReading)
async def get_dashboard_stats(user: User = Depends(current_active_user)):
    latest_reading = await SensorReading.find(
        SensorReading.user_id == user.id
    ).sort(-SensorReading.timestamp).first_or_none()

    if not latest_reading:
        raise HTTPException(status_code=404, detail="No sensor data found")
    return latest_reading


@router.post("/sensor-reading", response_model=SensorReading)
async def create_sensor_reading(
    reading: SensorReadingCreate, 
    user: User = Depends(current_active_user)
):
    new_reading = SensorReading(
        user_id=user.id,
        **reading.dict(),
    )
    await new_reading.insert()
    return new_reading


import joblib
import pandas as pd
import numpy as np

# Load ML model once
MODEL_PATH = "../ML model/soil_model.pkl"
try:
    soil_data = joblib.load(MODEL_PATH)
    model = soil_data['model']
    le = soil_data['le']
    feature_cols = soil_data['feature_cols']
except Exception as e:
    print(f"Error loading ML model: {e}")
    model = None


@router.get("/analysis", response_model=AnalysisResponse)
async def get_soil_analysis(user: User = Depends(current_active_user)):
    if model is None:
         raise HTTPException(status_code=500, detail="ML Model not loaded")
    # Get last 6 readings (required for engineering features in this specific model)
    readings = await SensorReading.find(
        SensorReading.user_id == user.id
    ).sort(-SensorReading.timestamp).limit(6).to_list()

    if len(readings) < 6:
        raise HTTPException(status_code=400, detail="At least 6 sensor readings required for ML analysis")

    # Reverse to chronological order for feature extraction
    readings.reverse()
    
    n = np.array([r.nitrogen for r in readings])
    p = np.array([r.phosphorus for r in readings])
    k = np.array([r.potassium for r in readings])
    m = np.array([r.moisture for r in readings])

    # Extract features matching the model training (soil_model.py)
    sample_features = {
        'N_mean':    np.mean(n),
        'P_mean':    np.mean(p),
        'K_mean':    np.mean(k),
        'M_mean':    np.mean(m),
        'N_max':     np.max(n),
        'P_max':     np.max(p),
        'K_max':     np.max(k),
        'N_min':     np.min(n),
        'M_min':     np.min(m),
        'N_spike':   n[-2] - n[0],
        'P_spike':   p[-2] - p[0],
        'K_spike':   k[-2] - k[0],
        'M_drop':    m[0] - m[-1],
        'N_std':     np.std(n),
        'P_std':     np.std(p),
        'K_std':     np.std(k),
        'M_std':     np.std(m),
        'NPK_rise_M_drop_ratio': float(np.clip((n[-2] - n[0] + 1) / (m[0] - m[-1] + 1), -1000, 1000)),
        'N_early_spike': n[2] - n[0],
    }

    X_input = np.array([[sample_features[f] for f in feature_cols]])
    pred_enc = model.predict(X_input)[0]
    pred_label = le.inverse_transform([pred_enc])[0]
    
    interpretations = {
        'inorganic':     '⚠️ High inorganic fertilizer detected. Sharp NPK spike with moisture drop — likely synthetic salt (urea/DAP).',
        'organic_manure':'🌿 Organic manure profile. Slow nutrient release, moisture stable — healthy organic input.',
        'control':       '✅ Normal healthy soil. Moderate NPK, stable moisture — no recent fertilization.',
        'depleted':      '❌ Depleted soil. Low NPK and moisture — soil needs nutrient replenishment.',
    }

    is_organic = pred_label in ['organic_manure', 'control']
    score = 90 if is_organic else 60

    return AnalysisResponse(
        healthScore=score,
        isOrganic=is_organic,
        label=pred_label,
        interpretation=interpretations.get(pred_label, "Unknown profile"),
        metrics={"npk": "Optimal" if is_organic else "Chemical Spike", "moisture": "Stable" if is_organic else "Fluctuating"},
    )


@router.get("/trends", response_model=TrendsResponse)
async def get_trends(range: str, user: User = Depends(current_active_user)):
    from datetime import datetime, timedelta
    now = datetime.utcnow()
    
    if range == "hour":
        delta = timedelta(hours=1)
    elif range == "day":
        delta = timedelta(days=1)
    else: # week
        delta = timedelta(days=7)
        
    since = now - delta
    
    readings = await SensorReading.find(
        SensorReading.user_id == user.id,
        SensorReading.timestamp >= since
    ).sort(+SensorReading.timestamp).to_list()

    return TrendsResponse(
        nitrogen=[r.nitrogen for r in readings],
        phosphorus=[r.phosphorus for r in readings],
        potassium=[r.potassium for r in readings],
        moisture=[r.moisture for r in readings],
        timestamps=[r.timestamp.isoformat() for r in readings],
    )


@router.get("/alerts", response_model=List[Alert])
async def get_alerts(user: User = Depends(current_active_user)):
    alerts = await Alert.find(
        Alert.user_id == user.id,
        Alert.is_active == True,
    ).sort(-Alert.timestamp).to_list()

    return alerts
