"""
Soil Classification Model - Phase 1
=====================================
Trains a Random Forest on the synthetic dataset.
Uses DTW-inspired time-series features + Random Forest.
Run this file to train and interactively test the model.
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.preprocessing import LabelEncoder
import joblib
import warnings
warnings.filterwarnings('ignore')

# ─────────────────────────────────────────────
# STEP 1: LOAD DATASET
# ─────────────────────────────────────────────

def load_data(path='soil_phase1_dataset.csv'):
    df = pd.read_csv(path)
    print(f"✓ Loaded dataset: {len(df)} rows, {df['label'].nunique()} classes")
    print(f"  Classes: {df['label'].unique().tolist()}")
    return df


# ─────────────────────────────────────────────
# STEP 2: FEATURE ENGINEERING
# Convert raw time-series into meaningful features
# per sample (one row per sample_id)
# ─────────────────────────────────────────────

def engineer_features(df):
    """
    For each sample, extract:
    - Mean value of N, P, K, Moisture across all time points
    - Max value (captures spike peak)
    - Spike rate = (value at t=60) - (value at t=0)  ← key inorganic signal
    - Moisture drop = moisture at t=0 minus t=120     ← osmotic effect signal
    - NPK rise / Moisture drop ratio                  ← correlation feature
    - Std deviation of N, P, K (high std = spike)
    """
    features = []

    for sample_id, group in df.groupby('sample_id'):
        group = group.sort_values('time_min')
        label = group['label'].iloc[0]

        n = group['N_mg_kg'].values
        p = group['P_mg_kg'].values
        k = group['K_mg_kg'].values
        m = group['moisture_pct'].values

        row = {
            # Raw stats
            'N_mean':    np.mean(n),
            'P_mean':    np.mean(p),
            'K_mean':    np.mean(k),
            'M_mean':    np.mean(m),

            'N_max':     np.max(n),
            'P_max':     np.max(p),
            'K_max':     np.max(k),

            'N_min':     np.min(n),
            'M_min':     np.min(m),

            # Spike rate (t=0 to t=60min) ← MOST IMPORTANT for inorganic detection
            'N_spike':   n[-2] - n[0],   # t=60 minus t=0
            'P_spike':   p[-2] - p[0],
            'K_spike':   k[-2] - k[0],

            # Moisture drop (inorganic causes osmotic moisture loss)
            'M_drop':    m[0] - m[-1],   # t=0 minus t=120

            # Std dev (high = spiked, low = flat)
            'N_std':     np.std(n),
            'P_std':     np.std(p),
            'K_std':     np.std(k),
            'M_std':     np.std(m),

            # Ratio: how much NPK rose vs how much moisture fell
            # High ratio = inorganic (NPK spikes AND moisture drops together)
            'NPK_rise_M_drop_ratio': float(np.clip((n[-2] - n[0] + 1) / (m[0] - m[-1] + 1), -1000, 1000)),

            # Early spike rate (t=0 to t=15min) - inorganic dissolves fast
            'N_early_spike': n[2] - n[0],  # t=15 minus t=0

            'label': label
        }
        features.append(row)

    feature_df = pd.DataFrame(features)
    print(f"✓ Engineered {len(feature_df.columns)-1} features for {len(feature_df)} samples")
    return feature_df


# ─────────────────────────────────────────────
# STEP 3: TRAIN MODEL
# ─────────────────────────────────────────────

def train_model(feature_df):
    feature_cols = [c for c in feature_df.columns if c != 'label']
    X = feature_df[feature_cols].values
    y = feature_df['label'].values

    le = LabelEncoder()
    y_enc = le.fit_transform(y)

    X_train, X_test, y_train, y_test = train_test_split(
        X, y_enc, test_size=0.2, random_state=42, stratify=y_enc
    )

    model = RandomForestClassifier(
        n_estimators=200,
        max_depth=None,
        min_samples_split=2,
        random_state=42,
        class_weight='balanced'
    )
    model.fit(X_train, y_train)

    # ── Evaluation ──
    y_pred = model.predict(X_test)
    print("\n" + "="*50)
    print("MODEL EVALUATION")
    print("="*50)

    acc = (y_pred == y_test).mean()
    print(f"\n✓ Test Accuracy: {acc*100:.1f}%")

    cv_scores = cross_val_score(model, X, y_enc, cv=5, scoring='accuracy')
    print(f"✓ 5-Fold Cross-validation: {cv_scores.mean()*100:.1f}% ± {cv_scores.std()*100:.1f}%")

    print("\nPer-class Performance:")
    print(classification_report(y_test, y_pred, target_names=le.classes_))

    print("Confusion Matrix (rows=actual, cols=predicted):")
    cm = confusion_matrix(y_test, y_pred)
    print(f"  Classes: {le.classes_.tolist()}")
    print(cm)

    # ── Feature Importance ──
    importances = model.feature_importances_
    feat_imp = sorted(zip(feature_cols, importances), key=lambda x: x[1], reverse=True)
    print("\nTop 5 Most Important Features:")
    for feat, imp in feat_imp[:5]:
        bar = '█' * int(imp * 100)
        print(f"  {feat:<30} {imp:.3f}  {bar}")

    return model, le, feature_cols


# ─────────────────────────────────────────────
# STEP 4: PREDICT FROM MANUAL INPUT
# User provides N, P, K, Moisture at each time point
# ─────────────────────────────────────────────

def predict_manual(model, le, feature_cols):
    """
    Takes manual N, P, K, Moisture readings at 6 time points
    and predicts soil class with confidence.
    """
    print("\n" + "="*50)
    print("TEST THE MODEL WITH YOUR OWN VALUES")
    print("="*50)
    print("Enter readings at 6 time points: 0, 5, 15, 30, 60, 120 minutes")
    print("(Or press ENTER to use a preset example)\n")

    presets = {
        '1': {
            'name': 'Inorganic fertilizer (high spike)',
            'N':    [120, 280, 520, 720, 840, 860],
            'P':    [80,  190, 340, 460, 530, 545],
            'K':    [100, 220, 430, 600, 680, 700],
            'M':    [56,  45,  33,  25,  20,  18 ],
        },
        '2': {
            'name': 'Organic manure (slow rise)',
            'N':    [118, 125, 138, 152, 170, 185],
            'P':    [74,  79,  87,  96,  108, 116],
            'K':    [95,  101, 112, 128, 148, 162],
            'M':    [54,  53,  52,  51,  50,  49 ],
        },
        '3': {
            'name': 'Healthy control soil',
            'N':    [128, 129, 130, 131, 132, 133],
            'P':    [82,  83,  83,  84,  84,  85 ],
            'K':    [105, 106, 106, 107, 107, 108],
            'M':    [48,  48,  47,  47,  47,  46 ],
        },
        '4': {
            'name': 'Depleted soil',
            'N':    [42,  43,  43,  44,  44,  45 ],
            'P':    [28,  28,  29,  29,  30,  30 ],
            'K':    [38,  39,  39,  40,  40,  41 ],
            'M':    [24,  24,  23,  23,  23,  22 ],
        },
    }

    while True:
        print("\nOptions:")
        print("  [1] Inorganic fertilizer example")
        print("  [2] Organic manure example")
        print("  [3] Healthy control example")
        print("  [4] Depleted soil example")
        print("  [5] Enter my own values")
        print("  [q] Quit")

        choice = input("\nYour choice: ").strip().lower()

        if choice == 'q':
            print("Exiting.")
            break

        if choice in presets:
            data = presets[choice]
            n = data['N']
            p = data['P']
            k = data['K']
            m = data['M']
            print(f"\nUsing preset: {data['name']}")

        elif choice == '5':
            print("\nEnter 6 values for each sensor (comma separated)")
            print("Time points: t=0, t=5, t=15, t=30, t=60, t=120 minutes")
            try:
                n = [float(x) for x in input("N (mg/kg): ").split(',')]
                p = [float(x) for x in input("P (mg/kg): ").split(',')]
                k = [float(x) for x in input("K (mg/kg): ").split(',')]
                m = [float(x) for x in input("Moisture (%): ").split(',')]
                if not all(len(x) == 6 for x in [n, p, k, m]):
                    print("❌ Please enter exactly 6 values for each sensor.")
                    continue
            except ValueError:
                print("❌ Invalid input. Use numbers separated by commas.")
                continue
        else:
            print("Invalid choice.")
            continue

        # Build features from input (same as training)
        n, p, k, m = np.array(n), np.array(p), np.array(k), np.array(m)

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
        proba = model.predict_proba(X_input)[0]

        print("\n" + "─"*40)
        print(f"  RESULT: {pred_label.upper().replace('_', ' ')}")
        print("─"*40)
        print("  Confidence breakdown:")
        for cls, prob in sorted(zip(le.classes_, proba), key=lambda x: x[1], reverse=True):
            bar = '█' * int(prob * 30)
            print(f"    {cls:<20} {prob*100:5.1f}%  {bar}")

        # Plain English interpretation
        print("\n  What this means:")
        interpretations = {
            'inorganic':     '⚠️  High inorganic fertilizer detected. Sharp NPK spike with moisture drop — likely synthetic salt (urea/DAP).',
            'organic_manure':'🌿  Organic manure profile. Slow nutrient release, moisture stable — healthy organic input.',
            'control':       '✅  Normal healthy soil. Moderate NPK, stable moisture — no recent fertilization.',
            'depleted':      '❌  Depleted soil. Low NPK and moisture — soil needs nutrient replenishment.',
        }
        print(f"  {interpretations.get(pred_label, '')}")
        print()


# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────

if __name__ == '__main__':
    print("="*50)
    print("  SOIL CLASSIFIER — PHASE 1")
    print("="*50)

    df           = load_data('soil_phase1_dataset.csv')
    feature_df   = engineer_features(df)
    model, le, feature_cols = train_model(feature_df)

    # Save model for Phase 2 (hardware integration)
    joblib.dump({'model': model, 'le': le, 'feature_cols': feature_cols}, 'soil_model.pkl')
    print("\n✓ Model saved to soil_model.pkl (ready for Phase 2 hardware integration)")

    predict_manual(model, le, feature_cols)
