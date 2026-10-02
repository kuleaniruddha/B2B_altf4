from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Callable, Dict, Optional

from jansampark_ai.schemas.common import AuthenticityFlags, TrustStatus


def _parse_exif_timestamp(exif_dict: Dict[str, Any]) -> Optional[datetime]:
    raw = exif_dict.get("DateTimeOriginal") or exif_dict.get("DateTime")
    if not raw:
        return None
    for fmt in ("%Y:%m:%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"):
        try:
            return datetime.strptime(raw, fmt)
        except ValueError:
            continue
    return None


def score_authenticity(
    image_path: str,
    exif_dict: Dict[str, Any],
    classifier_hook: Optional[Callable[[str, Dict[str, Any]], float]] = None,
) -> AuthenticityFlags:
    try:
        from PIL import Image
    except ImportError as exc:
        raise RuntimeError("Pillow is required for authenticity scoring.") from exc

    path = Path(image_path)
    with Image.open(path) as opened_image:
        image = opened_image.copy()
    reasons = []
    score = 1.0
    exif_present = bool(exif_dict)
    gps_present = bool(exif_dict.get("GPSInfo") or exif_dict.get("gps"))
    timestamp = _parse_exif_timestamp(exif_dict)
    timestamp_plausible = timestamp is not None and datetime.utcnow() - timedelta(days=3650) <= timestamp <= datetime.utcnow() + timedelta(days=1)
    metadata_stripped = not exif_present or (exif_present and len(exif_dict) <= 2)
    suspicious_encoding = path.suffix.lower() == ".png" and image.width >= 1080 and image.height >= 1920

    if not exif_present:
        score -= 0.25
        reasons.append("missing_exif")
    if not gps_present:
        score -= 0.15
        reasons.append("missing_gps")
    if not timestamp_plausible:
        score -= 0.20
        reasons.append("timestamp_implausible")
    if metadata_stripped:
        score -= 0.20
        reasons.append("metadata_stripped")
    if suspicious_encoding:
        score -= 0.15
        reasons.append("suspicious_encoding")

    if classifier_hook is not None:
        classifier_score = classifier_hook(image_path, exif_dict)
        score = min(score, classifier_score)
        if classifier_score < 0.5:
            reasons.append("classifier_flagged")

    if score < 0.45:
        trust_status = TrustStatus.REVIEW_REQUIRED
    elif score < 0.70:
        trust_status = TrustStatus.LOW_TRUST
    else:
        trust_status = TrustStatus.CLEAR

    return AuthenticityFlags(
        exif_present=exif_present,
        gps_present=gps_present,
        timestamp_plausible=timestamp_plausible,
        metadata_stripped=metadata_stripped,
        suspicious_encoding=suspicious_encoding,
        trust_status=trust_status,
        score=max(0.0, round(score, 3)),
        reasons=reasons,
    )
