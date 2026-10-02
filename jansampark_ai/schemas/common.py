from __future__ import annotations

from dataclasses import asdict, dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional


class IssueLabel(str, Enum):
    POTHOLE = "pothole"
    GARBAGE_DUMP = "garbage_dump"
    BROKEN_STREETLIGHT = "broken_streetlight"
    OVERFLOWING_BIN = "overflowing_bin"
    DRAINAGE_ISSUE = "drainage_issue"


class SeverityBucket(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class TrustStatus(str, Enum):
    CLEAR = "clear"
    LOW_TRUST = "low_trust"
    REVIEW_REQUIRED = "review_required"


@dataclass
class BoundingBox:
    x_min: float
    y_min: float
    x_max: float
    y_max: float

    def to_dict(self) -> Dict[str, float]:
        return asdict(self)


@dataclass
class Detection:
    label: str
    confidence: float
    box: BoundingBox

    def to_dict(self) -> Dict[str, Any]:
        payload = asdict(self)
        payload["box"] = self.box.to_dict()
        return payload


@dataclass
class WastePrediction:
    label: str
    confidence: float
    source_box_index: int
    scores: Dict[str, float] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class AuthenticityFlags:
    exif_present: bool
    gps_present: bool
    timestamp_plausible: bool
    metadata_stripped: bool
    suspicious_encoding: bool
    trust_status: TrustStatus
    score: float
    reasons: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        payload = asdict(self)
        payload["trust_status"] = self.trust_status.value
        return payload


@dataclass
class GPSLocation:
    lat: float
    lon: float
    accuracy_meters: Optional[float] = None

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class DeviceLatency:
    detector_ms: float = 0.0
    classifier_ms: float = 0.0
    total_ms: float = 0.0

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class ModelVersions:
    mobile_detector: str
    mobile_classifier: str
    cloud_verifier: str

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class SubmissionPayload:
    report_id: str
    image_uri: str
    gps: GPSLocation
    exif_summary: Dict[str, Any]
    image_hash: str
    mobile_detections: List[Detection]
    waste_predictions: List[WastePrediction]
    authenticity_flags: AuthenticityFlags
    model_versions: ModelVersions
    device_latency_ms: DeviceLatency

    def to_dict(self) -> Dict[str, Any]:
        return {
            "reportId": self.report_id,
            "imageUri": self.image_uri,
            "gps": self.gps.to_dict(),
            "exifSummary": self.exif_summary,
            "imageHash": self.image_hash,
            "mobileDetections": [item.to_dict() for item in self.mobile_detections],
            "wastePredictions": [item.to_dict() for item in self.waste_predictions],
            "authenticityFlags": self.authenticity_flags.to_dict(),
            "modelVersions": self.model_versions.to_dict(),
            "deviceLatencyMs": self.device_latency_ms.to_dict(),
        }


@dataclass
class VerificationRequest:
    report_id: str
    image_uri: str
    gps: GPSLocation
    exif_summary: Dict[str, Any]
    image_hash: str
    mobile_detections: List[Detection]
    waste_predictions: List[WastePrediction]
    authenticity_flags: AuthenticityFlags
    model_versions: ModelVersions
    device_latency_ms: DeviceLatency

    @classmethod
    def from_submission(cls, payload: SubmissionPayload) -> "VerificationRequest":
        return cls(
            report_id=payload.report_id,
            image_uri=payload.image_uri,
            gps=payload.gps,
            exif_summary=payload.exif_summary,
            image_hash=payload.image_hash,
            mobile_detections=payload.mobile_detections,
            waste_predictions=payload.waste_predictions,
            authenticity_flags=payload.authenticity_flags,
            model_versions=payload.model_versions,
            device_latency_ms=payload.device_latency_ms,
        )

    def to_dict(self) -> Dict[str, Any]:
        return SubmissionPayload(
            report_id=self.report_id,
            image_uri=self.image_uri,
            gps=self.gps,
            exif_summary=self.exif_summary,
            image_hash=self.image_hash,
            mobile_detections=self.mobile_detections,
            waste_predictions=self.waste_predictions,
            authenticity_flags=self.authenticity_flags,
            model_versions=self.model_versions,
            device_latency_ms=self.device_latency_ms,
        ).to_dict()


@dataclass
class VerificationResponse:
    validated_label: str
    final_confidence: float
    severity_bucket: SeverityBucket
    duplicate_of: Optional[str]
    trust_status: TrustStatus
    department_id: str
    review_required: bool

    def to_dict(self) -> Dict[str, Any]:
        payload = asdict(self)
        payload["severity_bucket"] = self.severity_bucket.value
        payload["trust_status"] = self.trust_status.value
        return payload
