import os
from pathlib import Path
from typing import List


def _get_env_list(key: str, default: str = "") -> List[str]:
    raw = os.getenv(key, default)
    if not raw:
        return []
    return [item.strip() for item in raw.split(",") if item.strip()]


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MODEL_PATH = PROJECT_ROOT / "assets" / "model" / "ham10000_efficientnetV2m_7class_torchscript.pt"

BACKSERVER_HOST: str = os.getenv("BACKSERVER_HOST", "0.0.0.0")
BACKSERVER_PORT: int = int(os.getenv("BACKSERVER_PORT", "8000"))
MODEL_PATH: str = os.getenv("MODEL_PATH", str(DEFAULT_MODEL_PATH))
# Optional override to force device selection (cpu|cuda|mps)
MODEL_DEVICE: str = os.getenv("MODEL_DEVICE", "").strip().lower()
BLUR_THRESHOLD: float = float(os.getenv("BLUR_THRESHOLD", "50.0"))
CONF_THRESHOLD: float = float(os.getenv("CONF_THRESHOLD", "0.5"))
RETRAIN_MIN_NEW_LABELS: int = int(os.getenv("RETRAIN_MIN_NEW_LABELS", "2"))
RETRAIN_DEFAULT_EPOCHS: int = int(os.getenv("RETRAIN_DEFAULT_EPOCHS", "1"))
RETRAIN_DEFAULT_BATCH_SIZE: int = int(os.getenv("RETRAIN_DEFAULT_BATCH_SIZE", "16"))
# Retrain device preference: "auto", "cuda", or "cpu"
RETRAIN_DEVICE: str = os.getenv("RETRAIN_DEVICE", "auto").strip().lower()
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
API_KEY: str = os.getenv("API_KEY", "abc123")
ENCRYPT_STORAGE: bool = os.getenv("ENCRYPT_STORAGE", "").strip().lower() in ("1", "true", "yes")
DATA_ENCRYPTION_KEY: str = os.getenv("DATA_ENCRYPTION_KEY", "").strip()
TLS_CERT_FILE: str = os.getenv("TLS_CERT_FILE", "").strip()
TLS_KEY_FILE: str = os.getenv("TLS_KEY_FILE", "").strip()

# JWT Authentication settings
JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-in-production")
JWT_ALGORITHM: str = os.getenv("JWT_ALGORITHM", "HS256")
JWT_EXPIRATION_HOURS: int = int(os.getenv("JWT_EXPIRATION_HOURS", "24"))

# User storage file path
USERS_FILE: str = os.getenv("USERS_FILE", os.path.join(os.path.dirname(__file__), "users.json"))

# Active Learning (AL) workspace configuration
AL_WORKSPACE_ROOT: str = os.path.join(os.path.dirname(__file__), "AL_Back")
AL_MODELS_DIR: str = os.path.join(AL_WORKSPACE_ROOT, "models")
AL_PRODUCTION_DIR: str = os.path.join(AL_MODELS_DIR, "production")
AL_CANDIDATES_DIR: str = os.path.join(AL_MODELS_DIR, "candidates")
AL_ARCHIVE_DIR: str = os.path.join(AL_MODELS_DIR, "archive")
AL_MODEL_REGISTRY_FILE: str = os.path.join(AL_WORKSPACE_ROOT, "db", "model_registry.json")
AL_LABELS_POOL_FILE: str = os.path.join(AL_WORKSPACE_ROOT, "db", "labels_pool.jsonl")
AL_EVENT_LOG_FILE: str = os.path.join(AL_WORKSPACE_ROOT, "db", "event_log.jsonl")
AL_ACTIVE_CONFIG_FILE: str = os.path.join(AL_WORKSPACE_ROOT, "config", "active_config.json")

# Active Learning candidate selection defaults
AL_CANDIDATES_TOP_K: int = int(os.getenv("AL_CANDIDATES_TOP_K", "5")) #เลือกtop k ว่าแสดงกี่caseดี
AL_CANDIDATES_INCLUDE_LABELED: bool = os.getenv("AL_CANDIDATES_INCLUDE_LABELED", "false").strip().lower() in ("1", "true", "yes") # ไม่รวมเคสที่เคยถูก label แล้ว(ไม่กลับมาคิดmarginอีก)
AL_CANDIDATES_ENTRY_TYPE: str = os.getenv("AL_CANDIDATES_ENTRY_TYPE", "").strip()
AL_CANDIDATES_STATUS: str = os.getenv("AL_CANDIDATES_STATUS", "").strip() # ถ้าว่างจะไม่กรองตามสถานะ ปรับให้กรองได้นะจ๊ะ
# Allowed entry types for annotation updates
AL_ANNOTATION_ENTRY_TYPES: List[str] = _get_env_list("AL_ANNOTATION_ENTRY_TYPES", "reject,case")

# Label map for skin lesion classification (HAM10000 classes)
LABEL_MAP: dict = {
    "akiec": 0, "bcc": 1, "bkl": 2, "df": 3, "mel": 4, "nv": 5, "vasc": 6
}
REVERSE_LABEL_MAP: dict = {v: k for k, v in LABEL_MAP.items()}

# Supported model architectures for Active Learning
class ModelArchitecture:
    EFFICIENTNET_V2_M = "efficientnet_v2_m"
    RESNET50 = "resnet50"

# Default architecture for new AL training
AL_DEFAULT_ARCHITECTURE: str = os.getenv("AL_DEFAULT_ARCHITECTURE", ModelArchitecture.EFFICIENTNET_V2_M)

# Base model paths for transfer learning (non-TorchScript checkpoints)
AL_BASE_MODELS: dict = {
    ModelArchitecture.EFFICIENTNET_V2_M: str(PROJECT_ROOT / "assets" / "models" / "ham10000_efficientNetV2m_7Class.pt"),
    ModelArchitecture.RESNET50: str(PROJECT_ROOT / "assets" / "models" / "ham10000_resnet50_7Class.pt"),
}
