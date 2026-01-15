#!/usr/bin/env python3
"""
One-time migration script to convert mock_credentials.csv to users.json with hashed passwords.

Usage:
    python migrate_users.py

This will read assets/mock_credentials.csv and create backserver/users.json with bcrypt-hashed passwords.
"""

import csv
import json
from pathlib import Path

import bcrypt


def hash_password(password: str) -> str:
    """Hash a password using bcrypt."""
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

# Paths
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = PROJECT_ROOT / "assets" / "mock_credentials.csv"
USERS_FILE = Path(__file__).resolve().parent / "users.json"


def migrate():
    """Read CSV and create users.json with hashed passwords."""
    if not CSV_PATH.exists():
        print(f"Error: CSV file not found at {CSV_PATH}")
        return False

    users = {}

    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        for row in reader:
            if not row:
                continue
            # Skip header row
            if row[0].strip().lower() in ("username", "#username"):
                continue

            if len(row) < 4:
                continue

            username = row[0].strip()
            password = row[1].strip()
            first_name = row[2].strip()
            last_name = row[3].strip()
            role = row[4].strip().lower() if len(row) >= 5 else ""

            # Hash the password
            password_hash = hash_password(password)

            users[username] = {
                "password_hash": password_hash,
                "first_name": first_name,
                "last_name": last_name,
                "role": role,
            }
            print(f"  Migrated user: {username} ({role})")

    # Save to JSON
    with open(USERS_FILE, "w", encoding="utf-8") as f:
        json.dump(users, f, indent=2, ensure_ascii=False)

    print(f"\nCreated {USERS_FILE} with {len(users)} users.")
    return True


if __name__ == "__main__":
    print("Migrating users from CSV to JSON with hashed passwords...\n")
    if migrate():
        print("\nMigration complete!")
    else:
        print("\nMigration failed.")
