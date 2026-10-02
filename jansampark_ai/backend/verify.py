from __future__ import annotations

from typing import Any, Dict, Iterable, Optional

from jansampark_ai.routing.department_router import route_issue
from jansampark_ai.schemas.common import (
    Detection,
    SeverityBucket,
    SubmissionPayload,
    TrustStatus,
    VerificationRequest,
    VerificationResponse,
)
from jansampark_ai.utils.firestore import upsert_report_fields
from jansampark_ai.utils.geo import encode_geohash
from jansampark_ai.validation.dedup import find_duplicate


def _best_mobile_detection(detections: Iterable[Detection]) -> Optional[Detection]:
    ranked = sorted(detections, key=lambda item: item.confidence, reverse=True)
    return ranked[0] if ranked else None


def _call_vertex(vertex_client: Any, request: VerificationRequest) -> Dict[str, Any]:
    payload = request.to_dict()
    if hasattr(vertex_client, "predict"):
        response = vertex_client.predict(instances=[payload])
        predictions = getattr(response, "predictions", response)
        return predictions[0] if isinstance(predictions, list) else predictions
    if callable(vertex_client):
        return vertex_client(payload)
    raise TypeError("vertex_client must expose predict() or be callable.")


def _severity_from_confidence(confidence: float) -> SeverityBucket:
    if confidence >= 0.85:
        return SeverityBucket.HIGH
    if confidence >= 0.60:
        return SeverityBucket.MEDIUM
    return SeverityBucket.LOW


def validate_report(payload: SubmissionPayload, firestore_client: Any, vertex_client: Any) -> VerificationResponse:
    duplicate_of = find_duplicate(payload.image_hash, payload.gps.lat, payload.gps.lon, firestore_client)
    request = VerificationRequest.from_submission(payload)
    cloud_result = _call_vertex(vertex_client, request)
    mobile_detection = _best_mobile_detection(payload.mobile_detections)
    mobile_label = mobile_detection.label if mobile_detection else "unknown"
    mobile_confidence = mobile_detection.confidence if mobile_detection else 0.0

    cloud_label = cloud_result.get("validatedLabel", mobile_label)
    cloud_confidence = float(cloud_result.get("finalConfidence", mobile_confidence))
    degraded_trust = payload.authenticity_flags.trust_status != TrustStatus.CLEAR
    cloud_authoritative = degraded_trust or cloud_confidence >= mobile_confidence
    final_label = cloud_label if cloud_authoritative else mobile_label
    final_confidence = cloud_confidence if cloud_authoritative else mobile_confidence
    severity = SeverityBucket(cloud_result.get("severityBucket", _severity_from_confidence(final_confidence).value))

    if duplicate_of:
        trust_status = TrustStatus.REVIEW_REQUIRED if degraded_trust else TrustStatus.LOW_TRUST
        review_required = True
    elif degraded_trust or final_confidence < 0.70 or final_label == "unknown":
        trust_status = TrustStatus.REVIEW_REQUIRED if degraded_trust else TrustStatus.LOW_TRUST
        review_required = True
    else:
        trust_status = TrustStatus.CLEAR
        review_required = False

    department_id = route_issue(final_label, firestore_client)
    response = VerificationResponse(
        validated_label=final_label,
        final_confidence=round(final_confidence, 4),
        severity_bucket=severity,
        duplicate_of=duplicate_of,
        trust_status=trust_status,
        department_id=department_id,
        review_required=review_required,
    )

    persistence_payload = {
        "aiLabel": response.validated_label,
        "aiConfidence": response.final_confidence,
        "severityBucket": response.severity_bucket.value,
        "trustStatus": response.trust_status.value,
        "departmentId": response.department_id,
        "duplicateOf": response.duplicate_of,
        "reviewRequired": response.review_required,
        "imageHash": payload.image_hash,
        "mobileModelVersion": payload.model_versions.mobile_detector,
        "cloudModelVersion": payload.model_versions.cloud_verifier,
        "geoHash": encode_geohash(payload.gps.lat, payload.gps.lon, precision=7),
        "lat": payload.gps.lat,
        "lon": payload.gps.lon,
    }
    upsert_report_fields(firestore_client, payload.report_id, persistence_payload)
    return response
