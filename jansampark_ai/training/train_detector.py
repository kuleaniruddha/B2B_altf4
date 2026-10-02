from __future__ import annotations

from pathlib import Path
from typing import Any, Dict

import yaml


def _load_config(config_path: str) -> Dict[str, Any]:
    return yaml.safe_load(Path(config_path).read_text(encoding="utf-8"))


def train_detector(config_path: str) -> str:
    config = _load_config(config_path)
    try:
        from ultralytics import YOLO
    except ImportError as exc:
        raise RuntimeError("Ultralytics is required to train the detector.") from exc

    model_name = config.get("model_name", "yolov10n.pt")
    model = YOLO(model_name)
    results = model.train(
        data=config["dataset_yaml"],
        epochs=config.get("epochs", 75),
        imgsz=config.get("imgsz", 512),
        batch=config.get("batch", 16),
        device=config.get("device", "cpu"),
        patience=config.get("patience", 15),
        workers=config.get("workers", 4),
        project=config.get("project_dir", "runs/detector"),
        name=config.get("experiment_name", "civic_detector"),
    )
    save_dir = Path(getattr(results, "save_dir", Path(config.get("project_dir", "runs/detector"))))
    weights_path = save_dir / "weights" / "best.pt"
    best_model = YOLO(str(weights_path))
    metrics = best_model.val(data=config["dataset_yaml"])
    metrics_path = save_dir / "validation_metrics.txt"
    metrics_path.write_text(str(metrics), encoding="utf-8")
    return str(weights_path)
