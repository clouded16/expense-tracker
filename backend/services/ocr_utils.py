import uuid
from pathlib import Path
from typing import Tuple

from fastapi import UploadFile, HTTPException

from PIL import Image
import io
import cv2
import numpy as np


def save_upload_file(upload_file: UploadFile, dest_dir: Path, max_size_bytes: int = 5 * 1024 * 1024) -> Tuple[Path, bytes]:
    data = upload_file.file.read()

    if not data:
        raise HTTPException(status_code=400, detail="Empty file")

    if len(data) > max_size_bytes:
        raise HTTPException(status_code=400, detail="File too large")

    # Try to detect if it's an image
    is_image = False
    try:
        Image.open(io.BytesIO(data)).verify()
        is_image = True
    except Exception:
        is_image = False

    content_type = upload_file.content_type or ""

    if not is_image and content_type != "application/pdf":
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {content_type}"
        )

    dest_dir.mkdir(parents=True, exist_ok=True)

    # Decide extension
    if is_image:
        ext = ".jpg"
    else:
        ext = ".pdf"

    filename = f"{uuid.uuid4().hex}{ext}"
    dest_path = dest_dir / filename

    with open(dest_path, "wb") as f:
        f.write(data)

    return dest_path, data


def _ext_for_content_type(content_type: str) -> str:
    if content_type == "image/jpeg":
        return ".jpg"
    if content_type == "image/png":
        return ".png"
    if content_type == "application/pdf":
        return ".pdf"
    return ""


def image_from_bytes(data: bytes):
    return Image.open(io.BytesIO(data)).convert("RGB")