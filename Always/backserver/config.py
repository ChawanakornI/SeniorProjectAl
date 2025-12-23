import os
from pathlib import Path
from typing import List


def _get_env_list(key: str, default: str = "") -> List[str]:
    raw = os.getenv(key, default)
    if not raw:
        return []
    return [item.strip() for item in raw.split(",") if item.strip()]


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MODEL_PATH = PROJECT_ROOT / "assets" / "models" / "ham10000_resnet50_tuned_best.pt"

BACKSERVER_HOST: str = os.getenv("BACKSERVER_HOST", "0.0.0.0")
BACKSERVER_PORT: int = int(os.getenv("BACKSERVER_PORT", "8000"))
MODEL_PATH: str = os.getenv("MODEL_PATH", str(DEFAULT_MODEL_PATH))
# Optional override to force device selection (cpu|cuda|mps)
MODEL_DEVICE: str = os.getenv("MODEL_DEVICE", "").strip().lower()
BLUR_THRESHOLD: float = float(os.getenv("BLUR_THRESHOLD", "100.0"))
CONF_THRESHOLD: float = float(os.getenv("CONF_THRESHOLD", "0.5"))
_storage_root = os.getenv("STORAGE_ROOT") or os.getenv("STORAGE_DIR")
STORAGE_ROOT: str = _storage_root or os.path.join(os.path.dirname(__file__), "storage")
USER_STORAGE_PREFIX: str = os.getenv("USER_STORAGE_PREFIX", "user")
METADATA_FILENAME: str = os.getenv("METADATA_FILENAME", "metadata.jsonl")
LEGACY_METADATA_FILE: str = os.getenv(
    "METADATA_FILE",
    os.path.join(STORAGE_ROOT, METADATA_FILENAME),
)
CASE_ID_START: int = int(os.getenv("CASE_ID_START", "10000"))
CASE_COUNTER_FILE: str = os.getenv(
    "CASE_COUNTER_FILE",
    os.path.join(STORAGE_ROOT, "case_counter.json"),
)
ALLOWED_ORIGINS: List[str] = _get_env_list("ALLOWED_ORIGINS", "*")
API_KEY: str = os.getenv("API_KEY", "")
ENCRYPT_STORAGE: bool = os.getenv("ENCRYPT_STORAGE", "").strip().lower() in ("1", "true", "yes")
DATA_ENCRYPTION_KEY: str = os.getenv("DATA_ENCRYPTION_KEY", "").strip()
TLS_CERT_FILE: str = os.getenv("TLS_CERT_FILE", "").strip()
TLS_KEY_FILE: str = os.getenv("TLS_KEY_FILE", "").strip()
