import os
import json
from pathlib import Path
from typing import List


def _get_env_list(key: str, default: str = "") -> List[str]:
    raw = os.getenv(key, default)
    if not raw:
        return []
    return [item.strip() for item in raw.split(",") if item.strip()]


PROJECT_ROOT = Path(__file__).resolve().parent.parent
MODEL_ASSETS_DIR = Path(os.getenv("MODEL_ASSETS_DIR", str(PROJECT_ROOT / "assets" / "models")))
_default_model_extensions = ".pt,.pth,.jit,.pth.tar"
MODEL_FILE_EXTENSIONS: List[str] = [
    ext.strip().lower()
    for ext in os.getenv("MODEL_FILE_EXTENSIONS", _default_model_extensions).split(",")
    if ext.strip()
]


def _is_supported_model_file(path: Path) -> bool:
    name = path.name.lower()
    for ext in MODEL_FILE_EXTENSIONS:
        if name.endswith(ext):
            return True
    return False


def _discover_default_model_path() -> str:
    # 1) Explicit env always wins.
    env_path = os.getenv("MODEL_PATH", "").strip()
    if env_path:
        return env_path

    # 2) Otherwise discover from assets/model (no hardcoded filename).
    if MODEL_ASSETS_DIR.exists():
        candidates = [
            p for p in MODEL_ASSETS_DIR.iterdir()
            if p.is_file() and _is_supported_model_file(p)
        ]
        if candidates:
            # Prefer TorchScript-like filenames for inference compatibility.
            candidates.sort(
                key=lambda p: (0 if "torchscript" in p.name.lower() else 1, p.name.lower())
            )
            return str(candidates[0])

    # 3) Fallback to empty (ModelService will run dummy mode if not set/found).
    return ""

BACKSERVER_HOST: str = os.getenv("BACKSERVER_HOST", "0.0.0.0")
BACKSERVER_PORT: int = int(os.getenv("BACKSERVER_PORT", "8000"))
MODEL_PATH: str = _discover_default_model_path()
# Optional override to force device selection (cpu|cuda|mps)
MODEL_DEVICE: str = os.getenv("MODEL_DEVICE", "").strip().lower()
BLUR_THRESHOLD: float = float(os.getenv("BLUR_THRESHOLD", "50.0"))
CONF_THRESHOLD: float = float(os.getenv("CONF_THRESHOLD", "0.5"))
RETRAIN_MIN_NEW_LABELS: int = int(os.getenv("RETRAIN_MIN_NEW_LABELS", "20"))
RETRAIN_DEFAULT_EPOCHS: int = int(os.getenv("RETRAIN_DEFAULT_EPOCHS", "10"))
RETRAIN_DEFAULT_BATCH_SIZE: int = int(os.getenv("RETRAIN_DEFAULT_BATCH_SIZE", "16"))
# Retrain device preference: "auto", "cuda", or "cpu"
RETRAIN_DEVICE: str = os.getenv("RETRAIN_DEVICE", "cuda").strip().lower()
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
AL_LABELS_USED_MODELS_FIELD: str = os.getenv("AL_LABELS_USED_MODELS_FIELD", "used_in_models")
AL_IMAGE_RETRAIN_HISTORY_FIELD: str = os.getenv("AL_IMAGE_RETRAIN_HISTORY_FIELD", "image_retrain_history")
AL_TRAINING_LOG_FILENAME: str = os.getenv("AL_TRAINING_LOG_FILENAME", "training_log.json")
# Force retraining to start from AL_BASE_MODELS (skip production model history).
# Set to "false" to restore production-first warm start behavior.
AL_FORCE_BASE_MODEL_ONLY: bool = os.getenv("AL_FORCE_BASE_MODEL_ONLY", "true").strip().lower() in ("1", "true", "yes")

# Experience Replay configuration (old data + new labeled data)
AL_EXPERIENCE_REPLAY_ENABLED: bool = os.getenv("AL_EXPERIENCE_REPLAY_ENABLED", "true").strip().lower() in ("1", "true", "yes")
AL_OLD_DATASET_DIR: str = os.getenv("AL_OLD_DATASET_DIR", str(PROJECT_ROOT / "assets" / "Old_Dataset"))
AL_OLD_DATA_CSV: str = os.getenv("AL_OLD_DATA_CSV", str(PROJECT_ROOT / "assets" / "HAM10000_metadata"))
AL_OLD_DATA_CSV_IMAGE_COLUMN: str = os.getenv("AL_OLD_DATA_CSV_IMAGE_COLUMN", "image_id").strip()
AL_OLD_DATA_CSV_LABEL_COLUMN: str = os.getenv("AL_OLD_DATA_CSV_LABEL_COLUMN", "dx").strip()
AL_REPLAY_OLD_QUOTA: int = int(os.getenv("AL_REPLAY_OLD_QUOTA", "150"))
AL_REPLAY_HERDING_RATIO: float = float(os.getenv("AL_REPLAY_HERDING_RATIO", "0.8"))
AL_REPLAY_RANDOM_RATIO: float = float(os.getenv("AL_REPLAY_RANDOM_RATIO", "0.2"))
AL_REPLAY_RANDOM_SEED: int = int(os.getenv("AL_REPLAY_RANDOM_SEED", "42"))
AL_REPLAY_IMAGE_SIZE: int = int(os.getenv("AL_REPLAY_IMAGE_SIZE", "224"))
AL_REPLAY_BATCH_SIZE: int = int(os.getenv("AL_REPLAY_BATCH_SIZE", "32"))
_default_old_label_map = {
    "akiec": "akiec",
    "bcc": "bcc",
    "bkl": "bkl",
    "df": "df",
    "mel": "mel",
    "nv": "nv",
    "vasc": "vasc",
    
}
AL_OLD_DATA_LABEL_MAP: dict = json.loads(os.getenv("AL_OLD_DATA_LABEL_MAP", json.dumps(_default_old_label_map)))
AL_SPLIT_SEED: int = int(os.getenv("AL_SPLIT_SEED", "42"))
AL_SPLIT_TRAIN_RATIO: float = float(os.getenv("AL_SPLIT_TRAIN_RATIO", "0.8"))

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
    MOBILENET_V3_LARGE = "mobilenet_v3_large"
    YOLO = "yolo"

# Default architecture for new AL training
AL_DEFAULT_ARCHITECTURE: str = os.getenv("AL_DEFAULT_ARCHITECTURE", ModelArchitecture.EFFICIENTNET_V2_M)

# Base model paths for transfer learning (non-TorchScript checkpoints)
AL_BASE_MODELS: dict = {
    ModelArchitecture.EFFICIENTNET_V2_M: str(PROJECT_ROOT / "assets" / "models" / "ham10000_efficientNetV2m_7Class.pt"),
    ModelArchitecture.RESNET50: str(PROJECT_ROOT / "assets" / "models" / "ham10000_resnet50_7Class.pt"),
    ModelArchitecture.MOBILENET_V3_LARGE: str(PROJECT_ROOT / "assets" / "models" / "best_skin_model(mobileNetV3(Dataset_pad)).pth"),
    ModelArchitecture.YOLO: str(PROJECT_ROOT / "assets" / "models" / "ham10000_yolo_7Class.pt"),
}

# YOLO retraining configuration
AL_YOLO_ENABLED: bool = os.getenv("AL_YOLO_ENABLED", "true").strip().lower() in ("1", "true", "yes")
AL_YOLO_TASK: str = os.getenv("AL_YOLO_TASK", "classify").strip().lower()
AL_YOLO_PRETRAINED_WEIGHTS: str = os.getenv("AL_YOLO_PRETRAINED_WEIGHTS", "yolo11n-cls.pt").strip()
AL_YOLO_IMG_SIZE: int = int(os.getenv("AL_YOLO_IMG_SIZE", "224"))
AL_YOLO_PATIENCE: int = int(os.getenv("AL_YOLO_PATIENCE", "20"))
AL_YOLO_WORKERS: int = int(os.getenv("AL_YOLO_WORKERS", "0"))
AL_YOLO_DATASET_DIRNAME: str = os.getenv("AL_YOLO_DATASET_DIRNAME", "yolo_dataset").strip()
AL_YOLO_RUN_NAME: str = os.getenv("AL_YOLO_RUN_NAME", "yolo_train").strip()
AL_YOLO_SAVE_PERIOD: int = int(os.getenv("AL_YOLO_SAVE_PERIOD", "1"))
