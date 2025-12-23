import argparse
import csv
import json
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Set

from . import config, crypto_utils


def _normalize_user_id(user_id: Optional[str]) -> Optional[str]:
    if not user_id:
        return None
    cleaned = user_id.strip()
    if not cleaned:
        return None
    safe = "".join(ch for ch in cleaned if ch.isalnum() or ch in ("-", "_"))
    return safe or None


def _load_role_map() -> Dict[str, str]:
    credentials_path = config.PROJECT_ROOT / "assets" / "mock_credentials.csv"
    if not credentials_path.exists():
        return {}
    role_map: Dict[str, str] = {}
    with open(credentials_path, "r", encoding="utf-8") as file:
        reader = csv.reader(file)
        for row in reader:
            if not row:
                continue
            if row[0].strip().lower() in ("username", "#username"):
                continue
            user_id = _normalize_user_id(row[0])
            if not user_id:
                continue
            role = row[4].strip().lower() if len(row) >= 5 else ""
            if role:
                role_map[user_id] = role
    return role_map


def _serialize_metadata_entry(entry: Dict[str, Any]) -> str:
    if crypto_utils.is_encryption_enabled():
        entry = crypto_utils.encrypt_json(entry)
    return json.dumps(entry, ensure_ascii=False)


def _load_metadata_entry(line: str) -> Optional[Dict[str, Any]]:
    try:
        entry = json.loads(line.strip())
    except json.JSONDecodeError:
        return None
    if isinstance(entry, dict) and "enc" in entry:
        try:
            return crypto_utils.decrypt_json(entry)
        except (ValueError, RuntimeError, json.JSONDecodeError):
            return None
    if isinstance(entry, dict):
        return entry
    return None


def _read_metadata_entries(metadata_path: Path) -> List[Dict[str, Any]]:
    entries: List[Dict[str, Any]] = []
    if not metadata_path.exists():
        return entries
    with open(metadata_path, "r", encoding="utf-8") as file:
        for line in file:
            entry = _load_metadata_entry(line)
            if entry:
                entries.append(entry)
    return entries


def _write_metadata_entries(
    metadata_path: Path,
    entries: Iterable[Dict[str, Any]],
    append: bool,
    dry_run: bool,
) -> None:
    if dry_run:
        return
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    mode = "a" if append else "w"
    with open(metadata_path, mode, encoding="utf-8") as file:
        for entry in entries:
            file.write(_serialize_metadata_entry(entry) + "\n")


def _gather_image_ids(entry: Dict[str, Any]) -> Set[str]:
    image_ids: Set[str] = set()
    image_id = entry.get("image_id")
    if isinstance(image_id, str) and image_id:
        image_ids.add(image_id)
    image_id_list = entry.get("image_ids")
    if isinstance(image_id_list, list):
        for item in image_id_list:
            if isinstance(item, str) and item:
                image_ids.add(item)
    return image_ids


def _move_image_files(
    image_ids: Iterable[str],
    legacy_root: Path,
    user_dir: Path,
    *,
    copy_only: bool,
    dry_run: bool,
) -> int:
    moved = 0
    for image_id in image_ids:
        for ext in (".jpg", ".bin"):
            src = legacy_root / f"{image_id}{ext}"
            if not src.exists():
                continue
            dest = user_dir / src.name
            if dry_run:
                moved += 1
                continue
            user_dir.mkdir(parents=True, exist_ok=True)
            if copy_only:
                dest.write_bytes(src.read_bytes())
            else:
                src.replace(dest)
            moved += 1
    return moved


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Migrate legacy backserver storage into per-user folders.",
    )
    parser.add_argument(
        "--default-user",
        default="user001",
        help="User ID to assign legacy records without a user_id field.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing user metadata.jsonl files instead of appending.",
    )
    parser.add_argument(
        "--copy",
        action="store_true",
        help="Copy files instead of moving them.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report actions without writing or moving files.",
    )
    args = parser.parse_args()

    legacy_root = Path(config.STORAGE_ROOT)
    legacy_metadata_path = Path(config.LEGACY_METADATA_FILE)
    if not legacy_metadata_path.exists():
        print(f"No legacy metadata file found at {legacy_metadata_path}")
        return

    default_user = _normalize_user_id(args.default_user) or "user001"
    role_map = _load_role_map()
    entries = _read_metadata_entries(legacy_metadata_path)
    if not entries:
        print("No legacy metadata entries found.")
        return

    entries_by_user: Dict[str, List[Dict[str, Any]]] = {}
    image_ids_by_user: Dict[str, Set[str]] = {}

    for entry in entries:
        user_id = _normalize_user_id(entry.get("user_id")) or default_user
        entry["user_id"] = user_id
        if not entry.get("user_role") and role_map.get(user_id):
            entry["user_role"] = role_map[user_id]
        entries_by_user.setdefault(user_id, []).append(entry)
        image_ids_by_user.setdefault(user_id, set()).update(_gather_image_ids(entry))

    total_written = 0
    total_moved = 0
    append = not args.overwrite
    for user_id, user_entries in entries_by_user.items():
        user_dir = legacy_root / user_id
        metadata_path = user_dir / config.METADATA_FILENAME
        _write_metadata_entries(metadata_path, user_entries, append, args.dry_run)
        total_written += len(user_entries)
        total_moved += _move_image_files(
            image_ids_by_user.get(user_id, set()),
            legacy_root,
            user_dir,
            copy_only=args.copy,
            dry_run=args.dry_run,
        )

    print(
        "Migration complete: "
        f"{total_written} metadata entries processed, "
        f"{total_moved} image files {'copied' if args.copy else 'moved'}."
    )
    if args.dry_run:
        print("Dry run enabled: no files were changed.")


if __name__ == "__main__":
    main()
