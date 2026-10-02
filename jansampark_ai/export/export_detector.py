from __future__ import annotations

import json
import shutil
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

import yaml

from jansampark_ai.export.metadata import attach_basic_tflite_metadata
from jansampark_ai.utils.artifacts import benchmark_stub, ensure_dir, save_json


def _load_config(config_path: str) -> Dict[str, Any]:
    return yaml.safe_load(Path(config_path).read_text(encoding="utf-8"))


def _artifact_dir(root: str, model_family: str, quant_mode: str) -> Path:
    stamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    return ensure_dir(Path(root) / "detector" / f"{model_family}_{quant_mode}_{stamp}")


def _preprocessing_payload(config: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "inputSize": config["detector"]["input_size"],
        "channelOrder": config["channel_order"],
        "normalization": config["normalization"]["detector"],
        "confidenceThreshold": config["detector"]["confidence_threshold"],
        "nms": {
            "requiredInWrapper": True,
            "iouThreshold": config["detector"]["nms_iou_threshold"],
        },
    }


def _representative_dataset(directory: str, input_size: int):
    try:
        import numpy as np
        import tensorflow as tf
        from PIL import Image
    except ImportError as exc:
        raise RuntimeError("TensorFlow, NumPy, and Pillow are required for detector quantization.") from exc

    for image_path in Path(directory).glob("*"):
        if image_path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
            continue
        image = Image.open(image_path).convert("RGB").resize((input_size, input_size))
        sample = np.asarray(image, dtype=np.float32)[None, ...]
        yield [tf.convert_to_tensor(sample)]


def _export_onnx(model_name: str, weights_path: str, onnx_path: Path, imgsz: int, opset: int) -> Path:
    try:
        from ultralytics import YOLO
    except ImportError as exc:
        raise RuntimeError("Ultralytics is required to export detector artifacts.") from exc

    model = YOLO(weights_path if Path(weights_path).exists() else model_name)
    exported_path = model.export(format="onnx", imgsz=imgsz, opset=opset, simplify=True)
    exported_onnx = Path(exported_path)
    if exported_onnx.resolve() != onnx_path.resolve():
        shutil.copy2(exported_onnx, onnx_path)
    return onnx_path


def _convert_onnx_to_saved_model(onnx_path: Path, saved_model_dir: Path) -> Path:
    try:
        from onnx2tf import convert
    except ImportError as exc:
        raise RuntimeError("onnx2tf is required for detector ONNX to TensorFlow conversion.") from exc

    convert(input_onnx_file_path=str(onnx_path), output_folder_path=str(saved_model_dir))
    return saved_model_dir


def _convert_saved_model_to_tflite(saved_model_dir: Path, tflite_path: Path, config: Dict[str, Any], quant_mode: str) -> None:
    try:
        import tensorflow as tf
    except ImportError as exc:
        raise RuntimeError("TensorFlow is required to export detector TFLite artifacts.") from exc

    converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model_dir))
    if quant_mode == "int8":
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.representative_dataset = lambda: _representative_dataset(
            config["detector"]["representative_dataset_dir"],
            config["detector"]["input_size"][0],
        )
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8
    else:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_path.write_bytes(converter.convert())


def _export_once(model_name: str, weights_path: str, config: Dict[str, Any], quant_mode: str, labels: List[str]) -> Path:
    artifact_dir = _artifact_dir(config["artifact_root"], Path(model_name).stem, quant_mode)
    with tempfile.TemporaryDirectory() as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        onnx_path = temp_dir / "model.onnx"
        saved_model_dir = temp_dir / "saved_model"
        _export_onnx(
            model_name=model_name,
            weights_path=weights_path,
            onnx_path=onnx_path,
            imgsz=config["detector"]["input_size"][0],
            opset=_load_config("configs/detector.yaml").get("onnx_opset", 13),
        )
        _convert_onnx_to_saved_model(onnx_path, saved_model_dir)
        destination = artifact_dir / "model.tflite"
        _convert_saved_model_to_tflite(saved_model_dir, destination, config, quant_mode)

    save_json(artifact_dir / "labels.json", {"labels": labels})
    save_json(artifact_dir / "preprocessing.json", _preprocessing_payload(config))
    save_json(
        artifact_dir / "metadata.json",
        {
            "name": config["detector"]["metadata"]["name"],
            "description": config["detector"]["metadata"]["description"],
            "framework": "tflite_flutter",
        },
    )
    save_json(artifact_dir / "metrics.json", {"parityCheck": "pending", "sourceWeights": weights_path, "exportPath": "onnx_to_tflite"})
    save_json(artifact_dir / "benchmark.json", benchmark_stub(Path(model_name).stem, quant_mode))
    attach_basic_tflite_metadata(
        destination,
        config["detector"]["metadata"]["name"],
        config["detector"]["metadata"]["description"],
        labels,
        config["normalization"]["detector"],
    )
    return artifact_dir


def export_detector_tflite(weights_path: str, export_config: str) -> str:
    config = _load_config(export_config)
    detector_config = _load_config("configs/detector.yaml")
    labels = detector_config["classes"]
    attempts = [
        (detector_config.get("model_name", "yolov10n.pt"), "int8"),
        (detector_config.get("model_name", "yolov10n.pt"), "dynamic"),
        (detector_config.get("fallback_model_name", "yolov10n.pt"), "int8"),
    ]
    errors = []
    for model_name, quant_mode in attempts:
        try:
            artifact_dir = _export_once(model_name, weights_path, config, quant_mode, labels)
            return str(artifact_dir)
        except Exception as exc:  # noqa: BLE001
            errors.append({"model": model_name, "mode": quant_mode, "error": str(exc)})
    raise RuntimeError(f"All detector export attempts failed: {json.dumps(errors, indent=2)}")
