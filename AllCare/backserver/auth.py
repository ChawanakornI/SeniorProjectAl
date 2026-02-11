"""JWT Authentication utilities for the backend."""

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional, Dict, Any

import bcrypt
import jwt
from fastapi import HTTPException, Header, status

from . import config


def hash_password(password: str) -> str:
    """Hash a password using bcrypt."""
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return bcrypt.checkpw(
        plain_password.encode("utf-8"),
        hashed_password.encode("utf-8"),
    )


def create_access_token(
    user_id: str,
    user_role: str,
    first_name: str = "",
    last_name: str = "",
) -> str:
    """Create a JWT access token with user claims."""
    expire = datetime.now(timezone.utc) + timedelta(hours=config.JWT_EXPIRATION_HOURS)
    payload = {
        "sub": user_id,
        "role": user_role,
        "first_name": first_name,
        "last_name": last_name,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, config.JWT_SECRET_KEY, algorithm=config.JWT_ALGORITHM)


def decode_token(token: str) -> Dict[str, Any]:
    """Decode and validate a JWT token. Raises HTTPException on failure."""
    try:
        payload = jwt.decode(
            token,
            config.JWT_SECRET_KEY,
            algorithms=[config.JWT_ALGORITHM],
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )


def load_users() -> Dict[str, Dict[str, Any]]:
    """Load users from the JSON file."""
    users_path = Path(config.USERS_FILE)
    if not users_path.exists():
        return {}
    try:
        with open(users_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}


def save_users(users: Dict[str, Dict[str, Any]]) -> None:
    """Save users to the JSON file."""
    users_path = Path(config.USERS_FILE)
    users_path.parent.mkdir(parents=True, exist_ok=True)
    with open(users_path, "w", encoding="utf-8") as f:
        json.dump(users, f, indent=2, ensure_ascii=False)


def get_user(username: str) -> Optional[Dict[str, Any]]:
    """Get a user by username."""
    users = load_users()
    return users.get(username)


def authenticate_user(username: str, password: str) -> Optional[Dict[str, Any]]:
    """Authenticate a user by username and password."""
    user = get_user(username)
    if not user:
        return None
    if not verify_password(password, user.get("password_hash", "")):
        return None
    return user


def get_current_user(
    authorization: Optional[str] = Header(default=None),
) -> Dict[str, str]:
    """
    FastAPI dependency to extract current user from JWT token.
    Expects Authorization header: 'Bearer <token>'
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )

    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Authorization header format. Expected: Bearer <token>",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = parts[1]
    payload = decode_token(token)

    return {
        "user_id": payload.get("sub", ""),
        "user_role": payload.get("role", ""),
        "first_name": payload.get("first_name", ""),
        "last_name": payload.get("last_name", ""),
    }
