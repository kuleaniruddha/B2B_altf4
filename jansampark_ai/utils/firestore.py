from __future__ import annotations

from typing import Any, Dict, Optional

from .constants import AI_CONFIG_COLLECTION, REPORTS_COLLECTION, ROUTING_DOCUMENT


def get_document(firestore_client: Any, collection: str, document_id: str) -> Optional[Dict[str, Any]]:
    doc = firestore_client.collection(collection).document(document_id).get()
    if getattr(doc, "exists", False):
        return doc.to_dict()
    return None


def upsert_report_fields(firestore_client: Any, report_id: str, payload: Dict[str, Any]) -> None:
    firestore_client.collection(REPORTS_COLLECTION).document(report_id).set(payload, merge=True)


def get_routing_config(firestore_client: Any) -> Optional[Dict[str, Any]]:
    return get_document(firestore_client, AI_CONFIG_COLLECTION, ROUTING_DOCUMENT)
