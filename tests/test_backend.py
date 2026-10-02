from __future__ import annotations

import unittest

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
)

from tests.test_core import FakeFirestore


class FakeVertexClient:
    def predict(self, instances):
        return {
            "validatedLabel": "pothole",
            "finalConfidence": 0.91,
            "severityBucket": "high",
        }


class BackendTests(unittest.TestCase):
    def test_validate_report_persists_verification_fields(self):
        firestore = FakeFirestore(
            {
                "ai_config": {
                    "department_routing": {
                        "labelMap": {"pothole": "roads_department_id"},
                        "reviewQueueDepartmentId": "review_queue_department_id",
                    }
                },
                "reports": {},
            }
        )
        payload = SubmissionPayload(
            report_id="report-123",
            image_uri="gs://bucket/image.jpg",
            gps=GPSLocation(lat=12.9716, lon=77.5946, accuracy_meters=3.0),
            exif_summary={"DateTimeOriginal": "2026:04:17 10:30:00", "GPSInfo": True},
            image_hash="aaaaaaaaaaaaaaaa",
            mobile_detections=[Detection(label="pothole", confidence=0.78, box=BoundingBox(1, 1, 20, 20))],
            waste_predictions=[],
            authenticity_flags=AuthenticityFlags(
                exif_present=True,
                gps_present=True,
                timestamp_plausible=True,
                metadata_stripped=False,
                suspicious_encoding=False,
                trust_status=TrustStatus.CLEAR,
                score=0.96,
            ),
            model_versions=ModelVersions("mobile-det-v1", "mobile-cls-v1", "cloud-det-v1"),
            device_latency_ms=DeviceLatency(detector_ms=130, classifier_ms=0, total_ms=130),
        )

        response = validate_report(payload, firestore, FakeVertexClient())
        persisted = firestore.store["reports"]["report-123"]
        self.assertEqual(response.validated_label, "pothole")
        self.assertEqual(persisted["departmentId"], "roads_department_id")
        self.assertEqual(persisted["severityBucket"], "high")


if __name__ == "__main__":
    unittest.main()
