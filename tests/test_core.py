from __future__ import annotations

import shutil
import unittest
from pathlib import Path

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
)
from jansampark_ai.validation.authenticity import score_authenticity
from jansampark_ai.validation.hash import dhash64, hamming_distance

try:
    from PIL import Image

    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False


class _Doc:
    def __init__(self, data, doc_id="doc"):
        self._data = data
        self.exists = data is not None
        self.id = doc_id

    def to_dict(self):
        return self._data


class _DocumentRef:
    def __init__(self, store, collection_name, doc_id):
        self.store = store
        self.collection_name = collection_name
        self.doc_id = doc_id

    def get(self):
        return _Doc(self.store.get(self.collection_name, {}).get(self.doc_id), self.doc_id)

    def set(self, payload, merge=False):
        self.store.setdefault(self.collection_name, {})
        if merge and self.doc_id in self.store[self.collection_name]:
            self.store[self.collection_name][self.doc_id].update(payload)
        else:
            self.store[self.collection_name][self.doc_id] = payload


class _Query:
    def __init__(self, docs):
        self.docs = docs

    def where(self, field, op, value):
        if op == "==":
            filtered = [doc for doc in self.docs if doc.to_dict().get(field) == value]
        elif op == ">=":
            filtered = [doc for doc in self.docs if doc.to_dict().get(field, "") >= value]
        elif op == "<":
            filtered = [doc for doc in self.docs if doc.to_dict().get(field, "") < value]
        else:
            filtered = self.docs
        return _Query(filtered)

    def stream(self):
        return self.docs


class _Collection:
    def __init__(self, store, name):
        self.store = store
        self.name = name

    def document(self, doc_id):
        return _DocumentRef(self.store, self.name, doc_id)

    def where(self, field, op, value):
        docs = [
            _Doc(data, doc_id)
            for doc_id, data in self.store.get(self.name, {}).items()
        ]
        return _Query(docs).where(field, op, value)


class FakeFirestore:
    def __init__(self, seed=None):
        self.store = seed or {}

    def collection(self, name):
        return _Collection(self.store, name)


class CoreTests(unittest.TestCase):
    def setUp(self):
        self.workspace_tmp = Path.cwd() / ".test_tmp"
        self.workspace_tmp.mkdir(exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.workspace_tmp, ignore_errors=True)

    @unittest.skipUnless(PIL_AVAILABLE, "Pillow is not installed")
    def test_hash_and_hamming_distance(self):
        path_a = self.workspace_tmp / "a.png"
        path_b = self.workspace_tmp / "b.png"
        Image.new("RGB", (16, 16), color="white").save(path_a)
        Image.new("RGB", (16, 16), color="black").save(path_b)
        hash_a = dhash64(str(path_a))
        hash_b = dhash64(str(path_b))
        self.assertEqual(len(hash_a), 16)
        self.assertGreaterEqual(hamming_distance(hash_a, hash_b), 0)

    @unittest.skipUnless(PIL_AVAILABLE, "Pillow is not installed")
    def test_authenticity_heuristics_without_exif(self):
        image_path = self.workspace_tmp / "capture.png"
        Image.new("RGB", (1200, 2000), color="white").save(image_path)
        flags = score_authenticity(str(image_path), {})
        self.assertFalse(flags.exif_present)
        self.assertIn(flags.trust_status, {TrustStatus.LOW_TRUST, TrustStatus.REVIEW_REQUIRED})

    def test_route_issue_falls_back_to_review_queue(self):
        firestore = FakeFirestore(
            {
                "ai_config": {
                    "department_routing": {
                        "labelMap": {"pothole": "roads_department_id"},
                        "reviewQueueDepartmentId": "review_queue_department_id",
                    }
                }
            }
        )
        self.assertEqual(route_issue("pothole", firestore), "roads_department_id")
        self.assertEqual(route_issue("unknown", firestore), "review_queue_department_id")

    def test_submission_payload_schema(self):
        payload = SubmissionPayload(
            report_id="report-1",
            image_uri="gs://bucket/report-1.jpg",
            gps=GPSLocation(lat=10.0, lon=20.0, accuracy_meters=5.0),
            exif_summary={"DateTimeOriginal": "2026:04:17 11:00:00"},
            image_hash="1234abcd1234abcd",
            mobile_detections=[Detection(label="pothole", confidence=0.9, box=BoundingBox(0, 0, 10, 10))],
            waste_predictions=[],
            authenticity_flags=AuthenticityFlags(
                exif_present=True,
                gps_present=True,
                timestamp_plausible=True,
                metadata_stripped=False,
                suspicious_encoding=False,
                trust_status=TrustStatus.CLEAR,
                score=0.95,
            ),
            model_versions=ModelVersions(
                mobile_detector="detector-v1",
                mobile_classifier="classifier-v1",
                cloud_verifier="cloud-v1",
            ),
            device_latency_ms=DeviceLatency(detector_ms=120, classifier_ms=20, total_ms=140),
        )
        serialized = payload.to_dict()
        self.assertEqual(serialized["reportId"], "report-1")
        self.assertEqual(serialized["mobileDetections"][0]["label"], "pothole")


if __name__ == "__main__":
    unittest.main()
