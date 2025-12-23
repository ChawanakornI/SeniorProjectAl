import base64
import json
import os
from functools import lru_cache
from typing import Any, Dict

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from . import config

_NONCE_SIZE = 12


def is_encryption_enabled() -> bool:
    return config.ENCRYPT_STORAGE


def _urlsafe_b64decode(value: str) -> bytes:
    padded = value + "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(padded.encode("ascii"))


def _get_key(*, require_enabled: bool) -> bytes:
    if require_enabled and not config.ENCRYPT_STORAGE:
        raise RuntimeError("Encryption is disabled")
    if not config.DATA_ENCRYPTION_KEY:
        raise RuntimeError("DATA_ENCRYPTION_KEY is not set")
    key = _urlsafe_b64decode(config.DATA_ENCRYPTION_KEY)
    if len(key) not in (16, 24, 32):
        raise RuntimeError("DATA_ENCRYPTION_KEY must decode to 16, 24, or 32 bytes")
    return key


@lru_cache(maxsize=2)
def _get_aesgcm(*, require_enabled: bool) -> AESGCM:
    return AESGCM(_get_key(require_enabled=require_enabled))


def encrypt_bytes(data: bytes) -> bytes:
    aesgcm = _get_aesgcm(require_enabled=True)
    nonce = os.urandom(_NONCE_SIZE)
    ciphertext = aesgcm.encrypt(nonce, data, None)
    return nonce + ciphertext


def decrypt_bytes(payload: bytes) -> bytes:
    if len(payload) < _NONCE_SIZE:
        raise ValueError("Encrypted payload is too short")
    aesgcm = _get_aesgcm(require_enabled=False)
    nonce = payload[:_NONCE_SIZE]
    ciphertext = payload[_NONCE_SIZE:]
    return aesgcm.decrypt(nonce, ciphertext, None)


def encrypt_json(entry: Dict[str, Any]) -> Dict[str, Any]:
    encoded = json.dumps(entry, ensure_ascii=False).encode("utf-8")
    payload = encrypt_bytes(encoded)
    return {"enc": base64.urlsafe_b64encode(payload).decode("ascii"), "v": 1}


def decrypt_json(wrapper: Dict[str, Any]) -> Dict[str, Any]:
    payload_b64 = wrapper.get("enc")
    if not isinstance(payload_b64, str):
        raise ValueError("Encrypted entry missing 'enc'")
    payload = _urlsafe_b64decode(payload_b64)
    decoded = decrypt_bytes(payload).decode("utf-8")
    data = json.loads(decoded)
    if not isinstance(data, dict):
        raise ValueError("Decrypted entry is not a JSON object")
    return data
