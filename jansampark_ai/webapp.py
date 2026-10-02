from __future__ import annotations

import json
import time
import uuid
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from PIL import ExifTags, Image, ImageStat

from jansampark_ai.backend.verify import validate_report
from jansampark_ai.schemas.common import (
    AuthenticityFlags,
    BoundingBox,
    Detection,
    DeviceLatency,
    GPSLocation,
    ModelVersions,
    SubmissionPayload,
    TrustStatus,
    WastePrediction,
)
from jansampark_ai.utils.constants import DEFAULT_ROUTING_CONFIG_PATH
from jansampark_ai.utils.geo import encode_geohash
from jansampark_ai.validation.authenticity import score_authenticity
from jansampark_ai.validation.dedup import find_duplicate
from jansampark_ai.validation.hash import dhash64

ISSUE_PROMPTS = {
    "pothole": "a road with a pothole or damaged asphalt",
    "garbage_dump": "a garbage dump or trash pile on a street",
    "broken_streetlight": "a broken or damaged streetlight on a road",
    "overflowing_bin": "an overflowing public trash bin",
    "drainage_issue": "a drainage issue with waterlogging or blocked drain",
    "no_issue": "a normal everyday photo with no civic issue to report",
    "suspicious_or_generated": "an AI generated image, synthetic illustration, portrait selfie, unrelated human photo, pet photo, or non-civic scene",
}

WASTE_PROMPTS = {
    "plastic": "plastic waste such as bottles or wrappers",
    "paper_cardboard": "paper or cardboard waste",
    "glass": "glass waste or broken glass",
    "metal": "metal waste such as cans or scrap",
    "organic": "organic waste such as food or leaves",
    "textile": "textile or cloth waste",
    "e_waste": "electronic waste such as cables or devices",
    "construction_debris": "construction debris such as concrete or bricks",
    "rubber": "rubber waste such as tires or rubber pieces",
    "mixed_waste": "mixed waste with multiple materials",
}


def extract_exif_summary(image_path: Path) -> Dict[str, Any]:
    exif_summary: Dict[str, Any] = {}
    with Image.open(image_path) as image:
        raw_exif = image.getexif()
        if not raw_exif:
            return exif_summary
        gps_info: Dict[str, Any] = {}
        for tag_id, value in raw_exif.items():
            tag = ExifTags.TAGS.get(tag_id, str(tag_id))
            if tag == "GPSInfo" and isinstance(value, dict):
                for gps_tag_id, gps_value in value.items():
                    gps_tag = ExifTags.GPSTAGS.get(gps_tag_id, str(gps_tag_id))
                    gps_info[gps_tag] = gps_value
                exif_summary["GPSInfo"] = gps_info
            else:
                exif_summary[tag] = value
    return exif_summary


def sanitize_for_json(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(key): sanitize_for_json(item) for key, item in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [sanitize_for_json(item) for item in value]
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return str(value)


def _image_features(image_path: Path) -> Dict[str, float]:
    with Image.open(image_path) as image:
        rgb = image.convert("RGB")
        gray = rgb.convert("L")
        stat = ImageStat.Stat(rgb)
        gray_stat = ImageStat.Stat(gray)
        width, height = rgb.size
        brightness = gray_stat.mean[0] / 255.0
        contrast = gray_stat.stddev[0] / 128.0
        red, green, blue = [channel / 255.0 for channel in stat.mean]
        return {
            "width": float(width),
            "height": float(height),
            "brightness": round(brightness, 4),
            "contrast": round(contrast, 4),
            "red": round(red, 4),
            "green": round(green, 4),
            "blue": round(blue, 4),
        }


@lru_cache(maxsize=1)
def _load_zero_shot_model() -> Tuple[Any, Any, Any]:
    try:
        import torch
        from transformers import AutoModelForZeroShotImageClassification, AutoProcessor
    except ImportError as exc:
        raise RuntimeError("Transformers and torch are required for real image prediction.") from exc

    model_id = "openai/clip-vit-base-patch32"
    processor = AutoProcessor.from_pretrained(model_id)
    model = AutoModelForZeroShotImageClassification.from_pretrained(model_id)
    model.eval()
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)
    return processor, model, device


def _softmax(values: List[float]) -> List[float]:
    import math

    if not values:
        return []
    max_value = max(values)
    exps = [math.exp(value - max_value) for value in values]
    total = sum(exps) or 1.0
    return [value / total for value in exps]


def _run_zero_shot_scores(image_path: Path, prompts: Dict[str, str]) -> Dict[str, float]:
    processor, model, device = _load_zero_shot_model()
    import torch

    with Image.open(image_path) as opened_image:
        image = opened_image.convert("RGB")
        inputs = processor(
            images=image,
            text=list(prompts.values()),
            return_tensors="pt",
            padding=True,
        )
    inputs = {key: value.to(device) for key, value in inputs.items()}
    with torch.no_grad():
        outputs = model(**inputs)
        logits = outputs.logits_per_image[0].detach().cpu().tolist()
    probabilities = _softmax(logits)
    return {
        label: round(probability, 4)
        for label, probability in zip(prompts.keys(), probabilities)
    }


def infer_actual_predictions(image_path: Path) -> Tuple[List[Detection], List[WastePrediction], Dict[str, Any]]:
    issue_scores = _run_zero_shot_scores(image_path, ISSUE_PROMPTS)
    issue_label, issue_confidence = max(issue_scores.items(), key=lambda item: item[1])
    civic_scores = {key: value for key, value in issue_scores.items() if key not in {"no_issue", "suspicious_or_generated"}}
    best_civic_label, best_civic_confidence = max(civic_scores.items(), key=lambda item: item[1])
    no_issue_score = issue_scores["no_issue"]
    suspicious_score = issue_scores["suspicious_or_generated"]

    final_issue_label = best_civic_label
    final_issue_confidence = best_civic_confidence

    # Reject unrelated images unless the civic class clearly dominates.
    if suspicious_score >= 0.34 and suspicious_score >= best_civic_confidence:
        final_issue_label = "suspicious_or_generated"
        final_issue_confidence = suspicious_score
    elif no_issue_score >= 0.34 and no_issue_score >= best_civic_confidence:
        final_issue_label = "no_issue"
        final_issue_confidence = no_issue_score
    elif best_civic_confidence < 0.33:
        if no_issue_score >= suspicious_score:
            final_issue_label = "no_issue"
            final_issue_confidence = no_issue_score
        else:
            final_issue_label = "suspicious_or_generated"
            final_issue_confidence = suspicious_score

    detections = [
        Detection(
            label=final_issue_label,
            confidence=round(final_issue_confidence, 4),
            box=BoundingBox(x_min=0.0, y_min=0.0, x_max=1.0, y_max=1.0),
        )
    ]

    waste_predictions: List[WastePrediction] = []
    waste_scores: Dict[str, float] = {}
    if final_issue_label in {"garbage_dump", "overflowing_bin"}:
        waste_scores = _run_zero_shot_scores(image_path, WASTE_PROMPTS)
        waste_label, waste_confidence = max(waste_scores.items(), key=lambda item: item[1])
        waste_predictions.append(
            WastePrediction(
                label=waste_label,
                confidence=round(waste_confidence, 4),
                source_box_index=0,
                scores=waste_scores,
            )
        )

    return detections, waste_predictions, {
        "mode": "zero_shot_clip",
        "issueScores": issue_scores,
        "bestCivicLabel": best_civic_label,
        "bestCivicConfidence": round(best_civic_confidence, 4),
        "decision": final_issue_label,
        "wasteScores": waste_scores,
        "features": _image_features(image_path),
        "note": "Predictions come from a real zero-shot vision model run on the uploaded image.",
    }


def build_submission_from_upload(
    image_path: Path,
    lat: float,
    lon: float,
    firestore_client: Any,
) -> Dict[str, Any]:
    started = time.perf_counter()
    exif_summary = extract_exif_summary(image_path)
    authenticity = score_authenticity(str(image_path), exif_summary)
    image_hash = dhash64(str(image_path))
    detections, waste_predictions, inference_info = infer_actual_predictions(image_path)
    duplicate_of = find_duplicate(image_hash, lat, lon, firestore_client)
    submission = SubmissionPayload(
        report_id=f"report-{uuid.uuid4().hex[:10]}",
        image_uri=str(image_path.resolve()),
        gps=GPSLocation(lat=lat, lon=lon, accuracy_meters=10.0),
        exif_summary=exif_summary,
        image_hash=image_hash,
        mobile_detections=detections,
        waste_predictions=waste_predictions,
        authenticity_flags=authenticity,
        model_versions=ModelVersions(
            mobile_detector="clip-zero-shot-issue-v1",
            mobile_classifier="clip-zero-shot-waste-v1",
            cloud_verifier="local-vertex-mock",
        ),
        device_latency_ms=DeviceLatency(
            detector_ms=18.0,
            classifier_ms=8.0 if waste_predictions else 0.0,
            total_ms=round((time.perf_counter() - started) * 1000, 2),
        ),
    )
    return {
        "submission": submission,
        "duplicate_of": duplicate_of,
        "inference": inference_info,
    }


def serialize_submission_result(
    submission: SubmissionPayload,
    verification: Dict[str, Any],
    duplicate_of: Optional[str],
    inference: Dict[str, Any],
) -> Dict[str, Any]:
    return {
        "reportId": submission.report_id,
        "imagePath": submission.image_uri,
        "issueLabel": verification["validated_label"],
        "confidence": verification["final_confidence"],
        "severity": verification["severity_bucket"],
        "departmentId": verification["department_id"],
        "reviewRequired": verification["review_required"],
        "duplicateOf": duplicate_of,
        "trustStatus": verification["trust_status"],
        "hash": submission.image_hash,
        "gps": submission.gps.to_dict(),
        "exifSummary": sanitize_for_json(submission.exif_summary),
        "authenticity": sanitize_for_json(submission.authenticity_flags.to_dict()),
        "detections": sanitize_for_json([item.to_dict() for item in submission.mobile_detections]),
        "wastePredictions": sanitize_for_json([item.to_dict() for item in submission.waste_predictions]),
        "latencyMs": sanitize_for_json(submission.device_latency_ms.to_dict()),
        "modelVersions": sanitize_for_json(submission.model_versions.to_dict()),
        "inference": sanitize_for_json(inference),
    }


def seed_open_report_from_submission(firestore_client: Any, submission: SubmissionPayload) -> None:
    firestore_client.collection("reports").document(submission.report_id).set(
        {
            "status": "OPEN",
            "geoHash": encode_geohash(submission.gps.lat, submission.gps.lon, precision=7),
            "lat": submission.gps.lat,
            "lon": submission.gps.lon,
            "imageHash": submission.image_hash,
            "aiLabel": submission.mobile_detections[0].label if submission.mobile_detections else "unknown",
        },
        merge=True,
    )
