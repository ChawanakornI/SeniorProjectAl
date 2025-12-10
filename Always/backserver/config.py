import os
from typing import List


def _get_env_list(key: str, default: str = "") -> List[str]:
    raw = os.getenv(key, default)
    if not raw:
        return []
    return [item.strip() for item in raw.split(",") if item.strip()]


BACKSERVER_HOST: str = os.getenv("BACKSERVER_HOST", "0.0.0.0")
BACKSERVER_PORT: int = int(os.getenv("BACKSERVER_PORT", "8000"))
MODEL_PATH: str = os.getenv("MODEL_PATH", "")
BLUR_THRESHOLD: float = float(os.getenv("BLUR_THRESHOLD", "100.0"))
CONF_THRESHOLD: float = float(os.getenv("CONF_THRESHOLD", "0.5"))
STORAGE_DIR: str = os.getenv("STORAGE_DIR", os.path.join(os.path.dirname(__file__), "storage"))
METADATA_FILE: str = os.getenv("METADATA_FILE", os.path.join(STORAGE_DIR, "metadata.jsonl"))
ALLOWED_ORIGINS: List[str] = _get_env_list("ALLOWED_ORIGINS", "*")
API_KEY: str = os.getenv("API_KEY", "")

