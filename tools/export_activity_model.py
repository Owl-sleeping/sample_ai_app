"""Train the prototype activity model and export it for the Flutter app.

Run with the project's Anaconda Python from the sample_demo_app directory:
    python tools/export_activity_model.py
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score


PROJECT_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_DIR.parent / "activity_analysis"
OUTPUT_PATH = PROJECT_DIR / "assets" / "activity_model.json"

SINGLE_FILES = {
    "stop_01.csv": "静止",
    "stop_02.csv": "静止",
    "walking_01.csv": "歩行",
    "walking_02.csv": "歩行",
    "running_01.csv": "走行",
    "running_02.csv": "走行",
}
MIXED_FILES = {"random_05.csv", "random_06.csv"}
MIXED_INTERVALS = [
    (0, 10, "歩行"),
    (10, 20, "静止"),
    (20, 25, "走行"),
    (25, 30, "歩行"),
]
FEATURES = ["magnitude_std", "magnitude_range", "magnitude_change"]


def make_features(filename: str, window_sec: float = 1.0) -> pd.DataFrame:
    frame = pd.read_csv(DATA_DIR / filename, encoding="utf-8-sig")
    frame["timestamp_local"] = pd.to_datetime(
        frame["timestamp_local"], errors="coerce"
    )
    frame = (
        frame.dropna(subset=["timestamp_local"])
        .sort_values("timestamp_local")
        .reset_index(drop=True)
    )
    elapsed = (
        frame["timestamp_local"] - frame["timestamp_local"].iloc[0]
    ).dt.total_seconds()
    magnitude = np.sqrt(
        frame["x_m_s2"] ** 2
        + frame["y_m_s2"] ** 2
        + frame["z_m_s2"] ** 2
    )

    rows = []
    duration = elapsed.max()
    for start in np.arange(0, duration - window_sec + 0.001, 1.0):
        end = start + window_sec
        label = SINGLE_FILES.get(filename)

        if filename in MIXED_FILES:
            label = None
            for interval_start, interval_end, activity in MIXED_INTERVALS:
                if start >= interval_start + 1 and end <= interval_end - 1:
                    label = activity
                    break
        if label is None:
            continue

        values = magnitude[(elapsed >= start) & (elapsed < end)].to_numpy()
        if len(values) < 2:
            continue
        rows.append(
            {
                "recording": filename,
                "activity": label,
                "window_start_sec": float(start),
                "magnitude_std": float(np.std(values, ddof=0)),
                "magnitude_range": float(np.max(values) - np.min(values)),
                "magnitude_change": float(np.mean(np.abs(np.diff(values)))),
            }
        )
    return pd.DataFrame(rows)


def export_tree(estimator) -> dict:
    tree = estimator.tree_
    counts = tree.value[:, 0, :]
    totals = counts.sum(axis=1, keepdims=True)
    probabilities = np.divide(
        counts,
        totals,
        out=np.zeros_like(counts, dtype=np.float64),
        where=totals != 0,
    )
    return {
        "left": tree.children_left.tolist(),
        "right": tree.children_right.tolist(),
        "feature": tree.feature.tolist(),
        "threshold": tree.threshold.tolist(),
        "values": probabilities.tolist(),
    }


def main() -> None:
    train_frames = [make_features(filename) for filename in SINGLE_FILES]
    train_frames.append(make_features("random_05.csv"))
    train = pd.concat(train_frames, ignore_index=True)
    test = make_features("random_06.csv")

    model = RandomForestClassifier(
        n_estimators=200,
        random_state=42,
        n_jobs=-1,
    )
    model.fit(train[FEATURES], train["activity"])
    validation_accuracy = accuracy_score(
        test["activity"], model.predict(test[FEATURES])
    )

    payload = {
        "model_name": "prototype_activity_random_forest",
        "model_version": 1,
        "window_seconds": 1.0,
        "update_seconds": 0.25,
        "features": FEATURES,
        "classes": model.classes_.tolist(),
        "trees": [export_tree(estimator) for estimator in model.estimators_],
        "training_recordings": list(SINGLE_FILES) + ["random_05.csv"],
        "validation_recording": "random_06.csv",
        "validation_accuracy": float(validation_accuracy),
        "training_windows": int(len(train)),
        "validation_windows": int(len(test)),
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"Exported: {OUTPUT_PATH}")
    print(f"Classes: {model.classes_.tolist()}")
    print(f"Training windows: {len(train)}")
    print(f"Validation windows: {len(test)}")
    print(f"Validation accuracy on random_06.csv: {validation_accuracy:.3f}")
    print(f"Trees: {len(model.estimators_)}")


if __name__ == "__main__":
    main()
