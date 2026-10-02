from __future__ import annotations

from pathlib import Path
from typing import Dict, List


def attach_basic_tflite_metadata(
    model_path: Path,
    model_name: str,
    description: str,
    labels: List[str],
    normalization: Dict[str, object],
) -> None:
    try:
        from tflite_support.metadata_writers import image_classifier, object_detector, writer_utils
    except ImportError:
        return

    model_buffer = model_path.read_bytes()
    label_file = model_path.with_name("labels.txt")
    label_file.write_text("\n".join(labels), encoding="utf-8")

    mean = normalization.get("mean", [0.0])
    std = normalization.get("std", [1.0])
    mean = [float(value) for value in mean]
    std = [float(value) for value in std]

    if "detector" in model_name.lower():
        writer = object_detector.MetadataWriter.create_for_inference(
            model_buffer=model_buffer,
            input_norm_mean=mean,
            input_norm_std=std,
            label_file_paths=[str(label_file)],
        )
    else:
        writer = image_classifier.MetadataWriter.create_for_inference(
            model_buffer=model_buffer,
            input_norm_mean=mean,
            input_norm_std=std,
            label_file_paths=[str(label_file)],
        )

    populated = writer.populate()
    writer_utils.save_file(populated, str(model_path))

