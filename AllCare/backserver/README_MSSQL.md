# Backend MS SQL Server Adaptation

This README describes a concrete implementation plan to replace the current
`metadata.jsonl` storage with Microsoft SQL Server, while keeping the FastAPI
routes and payloads stable for the Flutter app.

## Overview

Today the backend writes case logs and image check results to
`backserver/storage/metadata.jsonl`. This plan introduces a SQL Server database
and a small data-access layer so that:

- `/check-image` inserts into an `image_checks` table.
- `/cases`, `/cases/uncertain`, `/cases/reject` insert and read from a
  `case_logs` table.
- Existing response payloads remain the same shape.

The rest of the ML and image processing pipeline stays unchanged.

## Dependencies

Add the following Python packages:

```
sqlalchemy>=2.0
pyodbc>=5.0
```

On the host, install an ODBC driver:

- macOS: `brew install msodbcsql18`
- Ubuntu: `sudo apt-get install msodbcsql18`
- Windows: install "ODBC Driver 18 for SQL Server"

## Configuration (env vars)

Add these env vars (or a single `DATABASE_URL`):

```
DATABASE_URL="mssql+pyodbc://USER:PASSWORD@HOST:1433/DB?driver=ODBC+Driver+18+for+SQL+Server&Encrypt=yes&TrustServerCertificate=no"
```

If you prefer discrete vars, build the URL in `backserver/config.py`:

```
MSSQL_HOST
MSSQL_PORT=1433
MSSQL_DB
MSSQL_USER
MSSQL_PASSWORD
MSSQL_DRIVER="ODBC Driver 18 for SQL Server"
MSSQL_ENCRYPT=yes
MSSQL_TRUST_CERT=no
```

## Database schema

Use two tables to match existing behaviors.

```
CREATE TABLE case_logs (
  id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
  case_id NVARCHAR(64) NOT NULL,
  entry_type NVARCHAR(32) NOT NULL, -- case | uncertain | reject
  status NVARCHAR(32) NULL,
  created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  payload_json NVARCHAR(MAX) NOT NULL
);

CREATE INDEX idx_case_logs_case_id ON case_logs(case_id);
CREATE INDEX idx_case_logs_entry_type ON case_logs(entry_type);
CREATE INDEX idx_case_logs_status ON case_logs(status);

CREATE TABLE image_checks (
  id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
  case_id NVARCHAR(64) NOT NULL,
  image_id NVARCHAR(64) NOT NULL,
  blur_score FLOAT NOT NULL,
  status NVARCHAR(32) NOT NULL,
  predictions_json NVARCHAR(MAX) NOT NULL,
  created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE INDEX idx_image_checks_case_id ON image_checks(case_id);
```

`payload_json` stores the original case log payload so API responses can remain
identical to the JSONL-backed output.

## New files

Create a small database module and ORM models.

`backserver/db.py`:

```
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL is required for SQL Server backend")

engine = create_engine(DATABASE_URL, pool_pre_ping=True, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass
```

`backserver/db_models.py`:

```
import uuid
from sqlalchemy import Column, DateTime, Float, String, Text
from sqlalchemy.dialects.mssql import UNIQUEIDENTIFIER
from sqlalchemy.sql import func

from .db import Base


class CaseLogRow(Base):
    __tablename__ = "case_logs"
    id = Column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    case_id = Column(String(64), nullable=False)
    entry_type = Column(String(32), nullable=False)
    status = Column(String(32), nullable=True)
    created_at = Column(DateTime, nullable=False, server_default=func.sysutcdatetime())
    payload_json = Column(Text, nullable=False)


class ImageCheckRow(Base):
    __tablename__ = "image_checks"
    id = Column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    case_id = Column(String(64), nullable=False)
    image_id = Column(String(64), nullable=False)
    blur_score = Column(Float, nullable=False)
    status = Column(String(32), nullable=False)
    predictions_json = Column(Text, nullable=False)
    created_at = Column(DateTime, nullable=False, server_default=func.sysutcdatetime())
```

## Backserver changes

Replace JSONL writes/reads in `backserver/back.py` with database operations.

1) Add imports and a dependency for DB sessions:

```
import json
from sqlalchemy.orm import Session
from .db import SessionLocal
from .db_models import CaseLogRow, ImageCheckRow

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

2) Replace `_append_metadata` and `_log_case_entry`:

```
def _insert_case_log(db: Session, payload: dict, *, entry_type: str, default_status: str) -> CaseLogRow:
    entry = dict(payload)
    entry["entry_type"] = entry_type
    entry["status"] = entry.get("status") or default_status
    row = CaseLogRow(
        case_id=entry.get("case_id", ""),
        entry_type=entry_type,
        status=entry.get("status"),
        payload_json=json.dumps(entry),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row
```

3) In `/check-image`, insert into `image_checks`:

```
row = ImageCheckRow(
    case_id=case_id,
    image_id=image_id,
    blur_score=blur_score,
    status=status,
    predictions_json=json.dumps(predictions),
)
db.add(row)
db.commit()
```

4) In `/cases`, query `case_logs`, apply filters, and return payloads:

```
q = db.query(CaseLogRow).filter(CaseLogRow.entry_type.in_(allowed_entry_types))
if status:
    q = q.filter(CaseLogRow.status.ilike(status))
rows = q.order_by(CaseLogRow.created_at.desc()).limit(limit).all()
return {"cases": [json.loads(r.payload_json) for r in rows]}
```

5) Update endpoints to accept `db: Session = Depends(get_db)` and call the new
helpers.

## Optional: migrate existing JSONL

Create a one-off script to backfill the tables:

```
python backserver/scripts/migrate_metadata_jsonl.py
```

Pseudo-implementation:

```
for line in open(config.METADATA_FILE):
    entry = json.loads(line)
    entry_type = entry.get("entry_type") or "case"
    _insert_case_log(db, entry, entry_type=entry_type, default_status="pending")
```

## Notes and testing

- `payload_json` keeps responses identical to the legacy JSONL format.
- If SQL Server is unavailable, the API should fail fast rather than silently
  falling back to JSONL, to avoid split-brain data writes.
- Run `pytest` or `flutter test` is not required for this backend-only change,
  but validate with:

```
curl http://localhost:8000/health
curl -X POST http://localhost:8000/cases -H "Content-Type: application/json" \
  -d '{"case_id":"demo","status":"pending","created_at":"2024-01-01T00:00:00Z"}'
```

