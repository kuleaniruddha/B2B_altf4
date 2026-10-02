from __future__ import annotations

import json
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from jansampark_ai.backend.verify import validate_report
from jansampark_ai.routing.department_router import route_issue
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
from jansampark_ai.validation.dedup import find_duplicate
from jansampark_ai.webapp import (
    build_submission_from_upload,
    seed_open_report_from_submission,
    serialize_submission_result,
)


class GPSPayload(BaseModel):
    lat: float
    lon: float
    accuracy_meters: Optional[float] = None


class BoundingBoxPayload(BaseModel):
    x_min: float
    y_min: float
    x_max: float
    y_max: float


class DetectionPayload(BaseModel):
    label: str
    confidence: float
    box: BoundingBoxPayload


class WastePredictionPayload(BaseModel):
    label: str
    confidence: float
    source_box_index: int
    scores: Dict[str, float] = Field(default_factory=dict)


class AuthenticityPayload(BaseModel):
    exif_present: bool
    gps_present: bool
    timestamp_plausible: bool
    metadata_stripped: bool
    suspicious_encoding: bool
    trust_status: str
    score: float
    reasons: List[str] = Field(default_factory=list)


class ModelVersionsPayload(BaseModel):
    mobile_detector: str
    mobile_classifier: str
    cloud_verifier: str


class DeviceLatencyPayload(BaseModel):
    detector_ms: float = 0.0
    classifier_ms: float = 0.0
    total_ms: float = 0.0


class SubmissionPayloadModel(BaseModel):
    report_id: str
    image_uri: str
    gps: GPSPayload
    exif_summary: Dict[str, Any] = Field(default_factory=dict)
    image_hash: str
    mobile_detections: List[DetectionPayload] = Field(default_factory=list)
    waste_predictions: List[WastePredictionPayload] = Field(default_factory=list)
    authenticity_flags: AuthenticityPayload
    model_versions: ModelVersionsPayload
    device_latency_ms: DeviceLatencyPayload


class DuplicateCheckPayload(BaseModel):
    image_hash: str
    lat: float
    lon: float


class RouteIssuePayload(BaseModel):
    label: str


class _Doc:
    def __init__(self, payload: Optional[Dict[str, Any]], doc_id: str):
        self._payload = payload
        self.id = doc_id
        self.exists = payload is not None

    def to_dict(self) -> Dict[str, Any]:
        return self._payload or {}


class _DocumentRef:
    def __init__(self, store: Dict[str, Dict[str, Any]], collection_name: str, doc_id: str):
        self.store = store
        self.collection_name = collection_name
        self.doc_id = doc_id

    def get(self) -> _Doc:
        return _Doc(self.store.get(self.collection_name, {}).get(self.doc_id), self.doc_id)

    def set(self, payload: Dict[str, Any], merge: bool = False) -> None:
        self.store.setdefault(self.collection_name, {})
        if merge and self.doc_id in self.store[self.collection_name]:
            self.store[self.collection_name][self.doc_id].update(payload)
        else:
            self.store[self.collection_name][self.doc_id] = payload


class _Query:
    def __init__(self, docs: List[_Doc]):
        self.docs = docs

    def where(self, field: str, op: str, value: Any) -> "_Query":
        if op == "==":
            filtered = [doc for doc in self.docs if doc.to_dict().get(field) == value]
        elif op == ">=":
            filtered = [doc for doc in self.docs if doc.to_dict().get(field, "") >= value]
        elif op == "<":
            filtered = [doc for doc in self.docs if doc.to_dict().get(field, "") < value]
        else:
            filtered = self.docs
        return _Query(filtered)

    def stream(self) -> List[_Doc]:
        return self.docs


class _Collection:
    def __init__(self, store: Dict[str, Dict[str, Any]], name: str):
        self.store = store
        self.name = name

    def document(self, doc_id: str) -> _DocumentRef:
        return _DocumentRef(self.store, self.name, doc_id)

    def where(self, field: str, op: str, value: Any) -> _Query:
        docs = [_Doc(data, doc_id) for doc_id, data in self.store.get(self.name, {}).items()]
        return _Query(docs).where(field, op, value)


class LocalFirestoreClient:
    def __init__(self, seed: Optional[Dict[str, Dict[str, Any]]] = None):
        self.store = seed or {}

    def collection(self, name: str) -> _Collection:
        return _Collection(self.store, name)


class LocalVertexClient:
    def predict(self, instances: List[Dict[str, Any]]) -> Dict[str, Any]:
        payload = instances[0]
        detections = payload.get("mobileDetections", [])
        if detections:
            best = max(detections, key=lambda item: item.get("confidence", 0.0))
            confidence = float(best.get("confidence", 0.0))
            if confidence >= 0.85:
                severity = "high"
            elif confidence >= 0.6:
                severity = "medium"
            else:
                severity = "low"
            return {
                "validatedLabel": best.get("label", "unknown"),
                "finalConfidence": confidence,
                "severityBucket": severity,
            }
        return {
            "validatedLabel": "unknown",
            "finalConfidence": 0.0,
            "severityBucket": "low",
        }


def _load_default_store() -> Dict[str, Dict[str, Any]]:
    routing_payload = json.loads(Path(DEFAULT_ROUTING_CONFIG_PATH).read_text(encoding="utf-8"))
    return {
        "ai_config": {"department_routing": routing_payload},
        "reports": {},
    }


def _to_submission(payload: SubmissionPayloadModel) -> SubmissionPayload:
    return SubmissionPayload(
        report_id=payload.report_id,
        image_uri=payload.image_uri,
        gps=GPSLocation(
            lat=payload.gps.lat,
            lon=payload.gps.lon,
            accuracy_meters=payload.gps.accuracy_meters,
        ),
        exif_summary=payload.exif_summary,
        image_hash=payload.image_hash,
        mobile_detections=[
            Detection(
                label=item.label,
                confidence=item.confidence,
                box=BoundingBox(
                    x_min=item.box.x_min,
                    y_min=item.box.y_min,
                    x_max=item.box.x_max,
                    y_max=item.box.y_max,
                ),
            )
            for item in payload.mobile_detections
        ],
        waste_predictions=[
            WastePrediction(
                label=item.label,
                confidence=item.confidence,
                source_box_index=item.source_box_index,
                scores=item.scores,
            )
            for item in payload.waste_predictions
        ],
        authenticity_flags=AuthenticityFlags(
            exif_present=payload.authenticity_flags.exif_present,
            gps_present=payload.authenticity_flags.gps_present,
            timestamp_plausible=payload.authenticity_flags.timestamp_plausible,
            metadata_stripped=payload.authenticity_flags.metadata_stripped,
            suspicious_encoding=payload.authenticity_flags.suspicious_encoding,
            trust_status=TrustStatus(payload.authenticity_flags.trust_status),
            score=payload.authenticity_flags.score,
            reasons=payload.authenticity_flags.reasons,
        ),
        model_versions=ModelVersions(
            mobile_detector=payload.model_versions.mobile_detector,
            mobile_classifier=payload.model_versions.mobile_classifier,
            cloud_verifier=payload.model_versions.cloud_verifier,
        ),
        device_latency_ms=DeviceLatency(
            detector_ms=payload.device_latency_ms.detector_ms,
            classifier_ms=payload.device_latency_ms.classifier_ms,
            total_ms=payload.device_latency_ms.total_ms,
        ),
    )


app = FastAPI(title="Jansampark AI Local API", version="0.1.0")
app.state.firestore = LocalFirestoreClient(_load_default_store())
app.state.vertex = LocalVertexClient()
app.state.upload_dir = Path("uploads")
app.state.upload_dir.mkdir(exist_ok=True)
app.mount("/static", StaticFiles(directory="frontend"), name="static")


@app.get("/")
def frontend() -> FileResponse:
    return FileResponse("frontend/index.html")


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok"}


@app.get("/reports")
def list_reports() -> Dict[str, Any]:
    return {"reports": app.state.firestore.store.get("reports", {})}


@app.delete("/reports/{report_id}")
def delete_report(report_id: str) -> Dict[str, Any]:
    store = app.state.firestore.store.get("reports", {})
    if report_id in store:
        del store[report_id]
        return {"deleted": report_id, "status": "success"}
    raise HTTPException(status_code=404, detail=f"Report {report_id} not found")


@app.post("/analyze-image")
async def analyze_image(
    image: UploadFile = File(...),
    lat: float = Form(...),
    lon: float = Form(...),
) -> Dict[str, Any]:
    suffix = Path(image.filename or "upload.jpg").suffix or ".jpg"
    safe_name = f"{uuid.uuid4().hex}{suffix}"
    saved_path = app.state.upload_dir / safe_name
    saved_path.write_bytes(await image.read())

    prepared = build_submission_from_upload(saved_path, lat, lon, app.state.firestore)
    submission = prepared["submission"]
    duplicate_of = prepared["duplicate_of"]
    verification_response = validate_report(submission, app.state.firestore, app.state.vertex)
    seed_open_report_from_submission(app.state.firestore, submission)
    return serialize_submission_result(
        submission=submission,
        verification=verification_response.to_dict(),
        duplicate_of=duplicate_of,
        inference=prepared["inference"],
    )


@app.post("/route")
def route_issue_endpoint(payload: RouteIssuePayload) -> Dict[str, str]:
    department_id = route_issue(payload.label, app.state.firestore)
    return {"departmentId": department_id}


@app.post("/duplicate-check")
def duplicate_check(payload: DuplicateCheckPayload) -> Dict[str, Optional[str]]:
    duplicate_id = find_duplicate(payload.image_hash, payload.lat, payload.lon, app.state.firestore)
    return {"duplicateOf": duplicate_id}


@app.post("/verify")
def verify(payload: SubmissionPayloadModel) -> Dict[str, Any]:
    try:
        submission = _to_submission(payload)
        response = validate_report(submission, app.state.firestore, app.state.vertex)
        return response.to_dict()
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/seed-open-report")
def seed_open_report(payload: SubmissionPayloadModel) -> Dict[str, Any]:
    submission = _to_submission(payload)
    app.state.firestore.collection("reports").document(submission.report_id).set(
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
    return {"seeded": submission.report_id}
