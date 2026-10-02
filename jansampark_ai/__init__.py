"""Jansampark AI public API."""


def train_detector(config_path: str) -> str:
    from .training.train_detector import train_detector as _train_detector

    return _train_detector(config_path)


def train_waste_classifier(config_path: str) -> str:
    from .training.train_waste_classifier import train_waste_classifier as _train_classifier

    return _train_classifier(config_path)


def export_detector_tflite(weights_path: str, export_config: str) -> str:
    from .export.export_detector import export_detector_tflite as _export_detector

    return _export_detector(weights_path, export_config)


def export_classifier_tflite(weights_path: str, export_config: str) -> str:
    from .export.export_classifier import export_classifier_tflite as _export_classifier

    return _export_classifier(weights_path, export_config)


def score_authenticity(image_path: str, exif_dict: dict):
    from .validation.authenticity import score_authenticity as _score_authenticity

    return _score_authenticity(image_path, exif_dict)


def find_duplicate(image_hash: str, lat: float, lon: float, firestore_client):
    from .validation.dedup import find_duplicate as _find_duplicate

    return _find_duplicate(image_hash, lat, lon, firestore_client)


def validate_report(payload, firestore_client, vertex_client):
    from .backend.verify import validate_report as _validate_report

    return _validate_report(payload, firestore_client, vertex_client)


def route_issue(label: str, firestore_client) -> str:
    from .routing.department_router import route_issue as _route_issue

    return _route_issue(label, firestore_client)

__all__ = [
    "train_detector",
    "train_waste_classifier",
    "export_detector_tflite",
    "export_classifier_tflite",
    "score_authenticity",
    "find_duplicate",
    "validate_report",
    "route_issue",
]
