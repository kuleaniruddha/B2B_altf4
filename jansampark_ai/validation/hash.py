from __future__ import annotations


def dhash64(image_path: str, hash_size: int = 8) -> str:
    try:
        import imagehash
        from PIL import Image
    except ImportError as exc:
        raise RuntimeError("Pillow and imagehash are required for image hashing.") from exc

    with Image.open(image_path) as opened_image:
        image = opened_image.convert("RGB")
        return str(imagehash.dhash(image, hash_size=hash_size))


def hamming_distance(left_hash: str, right_hash: str) -> int:
    return (int(left_hash, 16) ^ int(right_hash, 16)).bit_count()
