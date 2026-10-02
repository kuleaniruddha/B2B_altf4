from __future__ import annotations

from pathlib import Path

from jansampark_ai.schemas.common import IssueLabel, SeverityBucket, TrustStatus

ISSUE_LABELS = [label.value for label in IssueLabel]
SEVERITY_BUCKETS = [bucket.value for bucket in SeverityBucket]
TRUST_STATES = [state.value for state in TrustStatus]
REPORTS_COLLECTION = "reports"
AI_CONFIG_COLLECTION = "ai_config"
ROUTING_DOCUMENT = "department_routing"
REVIEW_QUEUE_COLLECTION = "review_queue"
DEFAULT_ROUTING_CONFIG_PATH = Path("configs") / "routing.default.json"
