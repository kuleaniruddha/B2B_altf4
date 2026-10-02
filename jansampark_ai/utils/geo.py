from __future__ import annotations

import math
from typing import Iterable, Tuple

_BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"


def haversine_distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius = 6371000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = math.sin(delta_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    return 2 * radius * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def encode_geohash(lat: float, lon: float, precision: int = 8) -> str:
    lat_interval = [-90.0, 90.0]
    lon_interval = [-180.0, 180.0]
    geohash = []
    bit = 0
    ch = 0
    even = True
    bits = [16, 8, 4, 2, 1]
    while len(geohash) < precision:
        if even:
            mid = sum(lon_interval) / 2
            if lon >= mid:
                ch |= bits[bit]
                lon_interval[0] = mid
            else:
                lon_interval[1] = mid
        else:
            mid = sum(lat_interval) / 2
            if lat >= mid:
                ch |= bits[bit]
                lat_interval[0] = mid
            else:
                lat_interval[1] = mid
        even = not even
        if bit < 4:
            bit += 1
        else:
            geohash.append(_BASE32[ch])
            bit = 0
            ch = 0
    return "".join(geohash)


def neighbor_prefixes(geohash: str) -> Iterable[str]:
    if len(geohash) <= 1:
        return [geohash]
    return {geohash, geohash[:-1]}


def crop_box(box: Tuple[float, float, float, float], width: int, height: int) -> Tuple[int, int, int, int]:
    x_min, y_min, x_max, y_max = box
    return (
        max(0, min(width, int(x_min))),
        max(0, min(height, int(y_min))),
        max(0, min(width, int(x_max))),
        max(0, min(height, int(y_max))),
    )
