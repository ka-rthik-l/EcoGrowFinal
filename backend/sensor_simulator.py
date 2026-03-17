"""
NPK + Moisture Sensor Simulator
================================
Simulates sensor readings for 4 soil conditions, engineers features,
and classifies soil using the trained Random Forest model (soil_model.pkl).

Usage:
    uv run python sensor_simulator.py               # Run all 4 simulations
    uv run python sensor_simulator.py --interactive  # Enter custom values
"""

import os
import sys
import argparse
import numpy as np
import joblib

# ─────────────────────────────────────────────
# MODEL LOADING
# ─────────────────────────────────────────────

MODEL_PATH = os.path.join(os.path.dirname(__file__), "ML model", "soil_model.pkl")


def load_model(path=MODEL_PATH):
    """Load the trained model, label encoder, and feature column names."""
    if not os.path.exists(path):
        print(f"❌ Model not found at: {path}")
        print("   Run soil_model.py first to train and save the model.")
        sys.exit(1)

    data = joblib.load(path)
    print(f"✓ Loaded model from {path}")
    print(f"  Classes: {data['le'].classes_.tolist()}")
    print(f"  Features: {len(data['feature_cols'])}")
    return data["model"], data["le"], data["feature_cols"]


# ─────────────────────────────────────────────
# FEATURE ENGINEERING (matches soil_model.py)
# ─────────────────────────────────────────────


def engineer_features(n, p, k, m):
    """
    Build the same 19 features used during training.
    Expects arrays of 6 values each (time points: 0, 5, 15, 30, 60, 120 min).
    """
    n, p, k, m = np.array(n, dtype=float), np.array(p, dtype=float), \
                 np.array(k, dtype=float), np.array(m, dtype=float)

    return {
        "N_mean": np.mean(n),
        "P_mean": np.mean(p),
        "K_mean": np.mean(k),
        "M_mean": np.mean(m),
        "N_max": np.max(n),
        "P_max": np.max(p),
        "K_max": np.max(k),
        "N_min": np.min(n),
        "M_min": np.min(m),
        "N_spike": n[-2] - n[0],       # t=60 minus t=0
        "P_spike": p[-2] - p[0],
        "K_spike": k[-2] - k[0],
        "M_drop": m[0] - m[-1],        # t=0 minus t=120
        "N_std": np.std(n),
        "P_std": np.std(p),
        "K_std": np.std(k),
        "M_std": np.std(m),
        "NPK_rise_M_drop_ratio": float(
            np.clip((n[-2] - n[0] + 1) / (m[0] - m[-1] + 1), -1000, 1000)
        ),
        "N_early_spike": n[2] - n[0],  # t=15 minus t=0
    }


# ─────────────────────────────────────────────
# PREDICTION
# ─────────────────────────────────────────────


def predict(model, le, feature_cols, n, p, k, m):
    """Run prediction on a single set of sensor readings."""
    features = engineer_features(n, p, k, m)
    X = np.array([[features[f] for f in feature_cols]])

    pred_enc = model.predict(X)[0]
    pred_label = le.inverse_transform([pred_enc])[0]
    proba = model.predict_proba(X)[0]

    return pred_label, dict(zip(le.classes_, proba))


def print_result(label, probabilities, scenario_name=""):
    """Pretty-print a prediction result."""
    interpretations = {
        "inorganic":      "⚠️  High inorganic fertilizer detected. Sharp NPK spike "
                          "with moisture drop — likely synthetic salt (urea/DAP).",
        "organic_manure": "🌿  Organic manure profile. Slow nutrient release, "
                          "moisture stable — healthy organic input.",
        "control":        "✅  Normal healthy soil. Moderate NPK, stable moisture "
                          "— no recent fertilization.",
        "depleted":       "❌  Depleted soil. Low NPK and moisture — soil needs "
                          "nutrient replenishment.",
    }

    print()
    if scenario_name:
        print(f"  📌 Scenario: {scenario_name}")
    print("─" * 50)
    print(f"  🔬 RESULT:  {label.upper().replace('_', ' ')}")
    print("─" * 50)
    print("  Confidence breakdown:")
    for cls, prob in sorted(probabilities.items(), key=lambda x: x[1], reverse=True):
        bar = "█" * int(prob * 30)
        print(f"    {cls:<20} {prob*100:5.1f}%  {bar}")
    print()
    print(f"  {interpretations.get(label, '')}")
    print()


# ─────────────────────────────────────────────
# SENSOR SIMULATION PROFILES
# ─────────────────────────────────────────────
# Time points: 0, 5, 15, 30, 60, 120 minutes
# Each profile has base values; noise is added at runtime.


SCENARIOS = {
    "inorganic": {
        "name": "🧪 Inorganic Fertilizer (chemical spike)",
        "description": "Rapid NPK spike within 60 min, moisture drops sharply due to osmotic effect.",
        "N": [120, 280, 520, 720, 840, 860],
        "P": [80, 190, 340, 460, 530, 545],
        "K": [100, 220, 430, 600, 680, 700],
        "M": [56, 45, 33, 25, 20, 18],
    },
    "organic_manure": {
        "name": "🌿 Organic Manure (slow release)",
        "description": "Gradual NPK rise over 120 min, moisture stays stable.",
        "N": [118, 125, 138, 152, 170, 185],
        "P": [74, 79, 87, 96, 108, 116],
        "K": [95, 101, 112, 128, 148, 162],
        "M": [54, 53, 52, 51, 50, 49],
    },
    "control": {
        "name": "✅ Healthy Control Soil (no fertilizer)",
        "description": "Flat NPK levels, stable moisture — baseline healthy soil.",
        "N": [128, 129, 130, 131, 132, 133],
        "P": [82, 83, 83, 84, 84, 85],
        "K": [105, 106, 106, 107, 107, 108],
        "M": [48, 48, 47, 47, 47, 46],
    },
    "depleted": {
        "name": "❌ Depleted Soil (nutrient-poor)",
        "description": "Very low NPK and moisture — soil is exhausted.",
        "N": [42, 43, 43, 44, 44, 45],
        "P": [28, 28, 29, 29, 30, 30],
        "K": [38, 39, 39, 40, 40, 41],
        "M": [24, 24, 23, 23, 23, 22],
    },
}


def add_noise(values, noise_pct=0.05):
    """Add bounded random noise (±noise_pct) to simulate real sensor jitter."""
    arr = np.array(values, dtype=float)
    noise = arr * np.random.uniform(-noise_pct, noise_pct, size=arr.shape)
    return arr + noise


# ─────────────────────────────────────────────
# MAIN SIMULATION MODES
# ─────────────────────────────────────────────


def run_all_simulations(model, le, feature_cols):
    """Simulate all 4 soil conditions and classify them."""
    print("\n" + "=" * 55)
    print("  NPK + MOISTURE SENSOR SIMULATION")
    print("  Time points: 0, 5, 15, 30, 60, 120 minutes")
    print("=" * 55)

    results = []
    for key, scenario in SCENARIOS.items():
        # Add realistic sensor noise
        n = add_noise(scenario["N"])
        p = add_noise(scenario["P"])
        k = add_noise(scenario["K"])
        m = add_noise(scenario["M"])

        print(f"\n{'=' * 55}")
        print(f"  {scenario['name']}")
        print(f"  {scenario['description']}")
        print(f"{'=' * 55}")
        print(f"  Simulated readings (with sensor noise):")
        print(f"    {'Time (min)':<12} {'N (mg/kg)':>10} {'P (mg/kg)':>10} {'K (mg/kg)':>10} {'Moisture %':>10}")
        print(f"    {'─'*12} {'─'*10} {'─'*10} {'─'*10} {'─'*10}")
        time_points = [0, 5, 15, 30, 60, 120]
        for i, t in enumerate(time_points):
            print(
                f"    t={t:<8} {n[i]:>10.1f} {p[i]:>10.1f} {k[i]:>10.1f} {m[i]:>10.1f}"
            )

        label, probs = predict(model, le, feature_cols, n, p, k, m)
        print_result(label, probs, scenario["name"])

        correct = label == key
        results.append((key, label, correct, max(probs.values())))

    # Summary table
    print("\n" + "=" * 55)
    print("  SIMULATION SUMMARY")
    print("=" * 55)
    print(f"    {'Expected':<20} {'Predicted':<20} {'Confidence':>10}  {'Status'}")
    print(f"    {'─'*20} {'─'*20} {'─'*10}  {'─'*6}")
    all_correct = True
    for expected, predicted, correct, confidence in results:
        status = "✅" if correct else "❌"
        if not correct:
            all_correct = False
        print(
            f"    {expected:<20} {predicted:<20} {confidence*100:>9.1f}%  {status}"
        )
    print()
    if all_correct:
        print("  ✅ All 4 soil conditions classified correctly!")
    else:
        print("  ⚠️  Some conditions were misclassified. Check model or noise levels.")
    print()


def run_interactive(model, le, feature_cols):
    """Let the user enter custom sensor readings."""
    print("\n" + "=" * 55)
    print("  INTERACTIVE MODE — Enter Your Own Sensor Readings")
    print("=" * 55)
    print("  Time points: t=0, t=5, t=15, t=30, t=60, t=120 minutes")
    print("  Enter 6 comma-separated values for each sensor.\n")

    while True:
        try:
            n_input = input("  N (mg/kg) [6 values, comma separated]: ").strip()
            if n_input.lower() == "q":
                break
            p_input = input("  P (mg/kg) [6 values, comma separated]: ").strip()
            k_input = input("  K (mg/kg) [6 values, comma separated]: ").strip()
            m_input = input("  Moisture (%) [6 values, comma separated]: ").strip()

            n = [float(x.strip()) for x in n_input.split(",")]
            p = [float(x.strip()) for x in p_input.split(",")]
            k = [float(x.strip()) for x in k_input.split(",")]
            m = [float(x.strip()) for x in m_input.split(",")]

            if not all(len(x) == 6 for x in [n, p, k, m]):
                print("  ❌ Please enter exactly 6 values for each sensor.\n")
                continue

            label, probs = predict(model, le, feature_cols, n, p, k, m)
            print_result(label, probs, "Custom Input")

        except ValueError:
            print("  ❌ Invalid input. Use numbers separated by commas.\n")
        except (EOFError, KeyboardInterrupt):
            print("\n  Exiting.")
            break

        again = input("  Test another? (y/n): ").strip().lower()
        if again != "y":
            break

    print("  Done. 👋\n")


# ─────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Simulate NPK + Moisture sensors and classify soil condition."
    )
    parser.add_argument(
        "--interactive", "-i",
        action="store_true",
        help="Enter custom sensor values instead of running all simulations.",
    )
    parser.add_argument(
        "--no-noise",
        action="store_true",
        help="Disable random noise on simulated values (exact preset values).",
    )
    args = parser.parse_args()

    # Disable noise if requested
    if args.no_noise:
        add_noise = lambda values, noise_pct=0: np.array(values, dtype=float)  # noqa: E731

    model, le, feature_cols = load_model()

    if args.interactive:
        run_interactive(model, le, feature_cols)
    else:
        run_all_simulations(model, le, feature_cols)
