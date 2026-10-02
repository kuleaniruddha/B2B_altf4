from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable

import yaml

from jansampark_ai.export.metadata import attach_basic_tflite_metadata
from jansampark_ai.utils.artifacts import benchmark_stub, ensure_dir, save_json


def _load_config(config_path: str) -> Dict[str, Any]:
    return yaml.safe_load(Path(config_path).read_text(encoding="utf-8"))


def _artifact_dir(root: str, quant_mode: str) -> Path:
    stamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    return ensure_dir(Path(root) / "classifier" / f"efficientnet_b0_{quant_mode}_{stamp}")


def _representative_dataset(directory: str, input_size: int) -> Iterable[list[Any]]:
    try:
        from PIL import Image
    except ImportError as exc:
        raise RuntimeError("Pillow is required to build representative datasets for export.") from exc
    try:
        import numpy as np
    except ImportError as exc:
        raise RuntimeError("NumPy is required to build representative datasets for export.") from exc

    for image_path in Path(directory).glob("*"):
        if image_path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
            continue
        image = Image.open(image_path).convert("RGB").resize((input_size, input_size))
        sample = np.asarray(image, dtype=np.float32)[None, ...]
        yield [sample]


def export_classifier_tflite(weights_path: str, export_config: str) -> str:
    config = _load_config(export_config)
    classifier_config = _load_config("configs/classifier.yaml")
    try:
        import tensorflow as tf
    except ImportError as exc:
        raise RuntimeError("TensorFlow is required to export classifier artifacts.") from exc

    model = tf.keras.models.load_model(weights_path)
    quant_mode = config["classifier"]["quantization_modes"][0]
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    if quant_mode == "int8":
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.representative_dataset = lambda: _representative_dataset(
            config["classifier"]["representative_dataset_dir"],
            classifier_config.get("image_size", 224),
        )
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8
    tflite_model = converter.convert()

    artifact_dir = _artifact_dir(config["artifact_root"], quant_mode)
    model_path = artifact_dir / "model.tflite"
    model_path.write_bytes(tflite_model)
    save_json(artifact_dir / "labels.json", {"labels": classifier_config["classes"]})
    save_json(
        artifact_dir / "preprocessing.json",
        {
            "inputSize": [classifier_config.get("image_size", 224), classifier_config.get("image_size", 224)],
            "channelOrder": config["channel_order"],
            "normalization": config["normalization"]["classifier"],
            "topK": 3,
        },
    )
    save_json(
        artifact_dir / "metadata.json",
        {
            "name": config["classifier"]["metadata"]["name"],
            "description": config["classifier"]["metadata"]["description"],
            "framework": "tflite_flutter",
        },
    )
    save_json(artifact_dir / "metrics.json", {"sourceWeights": weights_path, "parityCheck": "pending"})
    save_json(artifact_dir / "benchmark.json", benchmark_stub("efficientnet_b0", quant_mode))
    attach_basic_tflite_metadata(
        model_path,
        config["classifier"]["metadata"]["name"],
        config["classifier"]["metadata"]["description"],
        classifier_config["classes"],
        config["normalization"]["classifier"],
    )
    return str(artifact_dir)
