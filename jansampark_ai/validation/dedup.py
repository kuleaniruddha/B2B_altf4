from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, Iterable, Optional

from jansampark_ai.utils.constants import REPORTS_COLLECTION
from jansampark_ai.utils.geo import encode_geohash, haversine_distance_meters, neighbor_prefixes
from jansampark_ai.validation.hash import dhash64, hamming_distance


def _iter_candidates(firestore_client: Any, lat: float, lon: float) -> Iterable[Dict[str, Any]]:
    geohash = encode_geohash(lat, lon, precision=7)
    for prefix in neighbor_prefixes(geohash):
        query = (
            firestore_client.collection(REPORTS_COLLECTION)
            .where("status", "==", "OPEN")
            .where("geoHash", ">=", prefix)
            .where("geoHash", "<", prefix + "~")
        )
        for doc in query.stream():
            payload = doc.to_dict()
            payload["id"] = getattr(doc, "id", payload.get("id"))
            yield payload


def _resolve_hash(image_hash_or_path: str) -> str:
    candidate = Path(image_hash_or_path)
    if candidate.exists():
        return dhash64(str(candidate))
    return image_hash_or_path


def find_duplicate(image_hash: str, lat: float, lon: float, firestore_client: Any) -> Optional[str]:
    source_hash = _resolve_hash(image_hash)
    for candidate in _iter_candidates(firestore_client, lat, lon):
        candidate_lat = candidate.get("lat")
        candidate_lon = candidate.get("lon")
        candidate_hash = candidate.get("imageHash")
        if candidate_lat is None or candidate_lon is None or not candidate_hash:
            continue
        distance = haversine_distance_meters(lat, lon, candidate_lat, candidate_lon)
        if distance > 50:
            continue
        if hamming_distance(source_hash, candidate_hash) <= 2:
            return candidate["id"]
    return None
