# AllCare Backend Server Documentation


## 📖 Table of Contents
1. [System Overview](#-system-overview)
2. [Architecture & Data Flow](#-architecture--data-flow)
3. [Visual Workflows](#-visual-workflows)
4. [Project Structure Deep Dive](#-project-structure-deep-dive)
5. [Setup & Installation](#-setup--installation)
6. [Authentication & Security](#-authentication--security)
7. [API Reference](#-api-reference)
8. [Configuration](#-configuration)
9. [AI Model Details](#-ai-model-details)
10. [Troubleshooting](#-troubleshooting)

---

## 🔭 System Overview

The **AllCare Backend** is a high-performance REST API built with **FastAPI**. It serves as the bridge between the Flutter mobile app and the AI diagnosis model, providing intelligent skin lesion analysis with continuous learning capabilities.

### Key Responsibilities
1.  **Authentication & Authorization:** Secure JWT-based user authentication with role-based access control (GP, Doctor, Admin).
2.  **Sanity Checks:** Validates uploaded images for clarity (Blur Detection) before processing.
3.  **AI Inference:** Loads a PyTorch ResNet50 model to classify skin lesions into 7 diagnostic categories.
4.  **Data Persistence:** Logs patient cases and saves images to the local file system with per-user isolation.
5.  **Active Learning:** Identifies uncertain cases requiring expert review using margin-based uncertainty sampling.
6.  **Model Retraining:** Supports continuous model improvement by retraining on labeled cases.
7.  **Annotation Management:** Collects and stores expert annotations for model refinement.
8.  **API Services:** Provides RESTful endpoints for the mobile app to consume.

---

## 🏗 Architecture & Data Flow

The system follows a layered architecture pattern. The diagram below shows how data moves from the app to the server and back.

![Architecture Diagram](https://mermaid.ink/img/Z3JhcGggVEQKICAgIENsaWVudFvwn5OxIEZsdXR0ZXIgTW9iaWxlIEFwcF0KICAgIEFQSVvwn5qAIEZhc3RBUEkgU2VydmVyXQogICAgRW5naW5lW/Cfp6AgQUkgSW5mZXJlbmNlIEVuZ2luZV0KICAgIFN0b3JhZ2Vb8J+TgiBMb2NhbCBTdG9yYWdlXQoKICAgIENsaWVudCAtLSAiMS4gUE9TVCAvY2hlY2staW1hZ2UiIC0tPiBBUEkKICAgIEFQSSAtLSAiMi4gVmFsaWRhdGUgJiBQcmVwcm9jZXNzIiAtLT4gQVBJCiAgICBBUEkgLS0gIjMuIFJlcXVlc3QgUHJlZGljdGlvbiIgLS0+IEVuZ2luZQogICAgRW5naW5lIC0tICI0LiBSZXR1cm4gUHJvYmFiaWxpdGllcyIgLS0+IEFQSQogICAgQVBJIC0tICI1LiBTYXZlIEltYWdlICYgTWV0YWRhdGEiIC0tPiBTdG9yYWdlCiAgICBBUEkgLS0gIjYuIEpTT04gUmVzcG9uc2UgKERpYWdub3NpcykiIC0tPiBDbGllbnQ=)

### Technology Stack
-   **Framework:** FastAPI (Python) - *Fast, async, and auto-validating.*
-   **Authentication:** PyJWT + bcrypt - *Secure JWT token authentication and password hashing.*
-   **Computer Vision:** OpenCV (`cv2`) - *Used for blur detection.*
-   **AI/ML:** PyTorch (`torch`) - *Runs the ResNet50 model.*
-   **Validation:** Pydantic - *Ensures data integrity for requests/responses.*
-   **Security:** Cryptography (optional) - *Fernet encryption for stored data.*

---

## 📊 Visual Workflows

### 1. Image Check Workflow (`/check-image`)
This is the core loop where the Doctor/GP takes a photo, and the server processes it.

![Sequence Diagram](https://mermaid.ink/img/c2VxdWVuY2VEaWFncmFtCiAgICBwYXJ0aWNpcGFudCBBcHAgYXMgTW9iaWxlIEFwcAogICAgcGFydGljaXBhbnQgU2VydmVyIGFzIEZhc3RBUEkgU2VydmVyCiAgICBwYXJ0aWNpcGFudCBDViBhcyBPcGVuQ1YgKEJsdXIgQ2hlY2spCiAgICBwYXJ0aWNpcGFudCBBSSBhcyBQeVRvcmNoIE1vZGVsCiAgICBwYXJ0aWNpcGFudCBEQiBhcyBGaWxlIFN0b3JhZ2UKCiAgICBBcHAtPj5TZXJ2ZXI6IFBPU1QgL2NoZWNrLWltYWdlIChmaWxlKQogICAgU2VydmVyLT4+Q1Y6IENhbGN1bGF0ZSBMYXBsYWNpYW4gVmFyaWFuY2UKICAgIENWLS0+PlNlcnZlcjogQmx1ciBTY29yZSAoZS5nLiwgMTIwLjUpCiAgICAKICAgIGFsdCBTY29yZSA8IFRocmVzaG9sZCAoMTAwLjApCiAgICAgICAgU2VydmVyLS0+PkFwcDogNDAwIEVycm9yIC8gIlRvbyBCbHVycnkiCiAgICBlbHNlIFNjb3JlID49IFRocmVzaG9sZAogICAgICAgIFNlcnZlci0+PkFJOiBQcmVkaWN0KGltYWdlKQogICAgICAgIEFJLS0+PlNlcnZlcjogUHJlZGljdGlvbnMgW01lbGFub21hOiA4MCUsIE5ldmk6IDE1JS4uLl0KICAgICAgICBTZXJ2ZXItPj5EQjogU2F2ZSBJbWFnZSAmIExvZyBNZXRhZGF0YQogICAgICAgIFNlcnZlci0tPj5BcHA6IDIwMCBPSyArIFByZWRpY3Rpb25zCiAgICBlbmQ=)

### 2. Case Logging Workflow
How final diagnoses are saved after the AI result is reviewed.

![Case Logging Diagram](https://mermaid.ink/img/Z3JhcGggTFIKICAgIFVzZXJbRG9jdG9yIENvbmZpcm1zIERpYWdub3Npc10gLS0+fFN1Ym1pdHwgQXBwCiAgICBBcHAgLS0+fFBPU1QgL2Nhc2VzfCBBUEkKICAgIEFQSSAtLT58VmFsaWRhdGUgRGF0YXwgU2NoZW1hW1B5ZGFudGljIFNjaGVtYV0KICAgIFNjaGVtYSAtLT58VmFsaWR8IExvZ2dlcltKU09OTCBMb2dnZXJdCiAgICBMb2dnZXIgLS0+fEFwcGVuZHwgRmlsZVtzdG9yYWdlL21ldGFkYXRhLmpzb25sXQogICAgQVBJIC0tPnxTdWNjZXNzfCBBcHA=)

### 3. Active Learning Workflow
How the system identifies uncertain cases for expert review:

```
1. Doctor requests uncertain cases → POST /active-learning/candidates
2. System analyzes all unlabeled cases in storage
3. For each case, calculates prediction margin (difference between top 2 predictions)
4. Ranks cases by uncertainty (lower margin = more uncertain)
5. Returns top-k most uncertain cases with uncertainty scores
6. Doctor reviews and labels uncertain cases
7. Labels stored in metadata for future retraining
```

**Key Insight:** Cases where the model predicts 85% Melanoma and 12% Nevus are more valuable to label than cases with 98% Melanoma and 1% Nevus. The former teaches the model to better distinguish similar conditions.

### 4. Model Retraining Workflow
Continuous improvement through expert feedback:

```
1. Admin triggers retraining → POST /model/retrain
2. System collects all labeled cases from storage
3. Verifies minimum threshold (≥5 labeled cases)
4. Loads base ResNet50 model
5. Fine-tunes on labeled cases (default: 5 epochs)
6. Saves updated model checkpoint
7. Updates retraining status file
8. New model becomes available for inference
```

**Requirements:**
- At least 5 labeled cases in storage
- Labeled cases from `/cases/{case_id}/label` or annotations endpoint
- Sufficient computational resources (GPU recommended)

---

## 📂 Project Structure Deep Dive

Here is an explanation of every important file in the `backserver/` directory:

```plaintext
backserver/
├── back.py                     # 🏁 ENTRY POINT
│   └── Initializes FastAPI, CORS, and defines all API Routes (@app.post, @app.get).
│
├── model.py                    # 🧠 THE BRAIN
│   ├── Loads the .pt model file securely.
│   ├── Preprocesses images (Resize -> CenterCrop -> Normalize).
│   └── Runs inference to get probability scores.
│
├── auth.py                     # 🔐 AUTHENTICATION
│   ├── JWT token creation and validation.
│   ├── Password hashing with bcrypt.
│   ├── User authentication and credential management.
│   └── Extracts user context from Authorization headers.
│
├── AL.py                       # 🎯 ACTIVE LEARNING
│   ├── Margin-based uncertainty sampling for case selection.
│   ├── Calculates prediction margins to identify uncertain cases.
│   └── Selects top-k cases requiring expert review.
│
├── retrain_model.py            # 🔄 MODEL RETRAINING
│   ├── Collects labeled cases from storage.
│   ├── Retrains ResNet50 model on new labeled data.
│   └── Tracks retraining status and saves updated models.
│
├── admin_user_manager.py       # 👤 USER MANAGEMENT CLI
│   ├── Interactive command-line tool for user administration.
│   ├── Create, update, delete, and list users.
│   └── Password reset and role management.
│
├── config.py                   # ⚙️ SETTINGS
│   └── Centralizes all constants (Paths, Thresholds, API Keys, JWT settings) using env vars.
│
├── schemas.py                  # 📝 DATA CONTRACTS
│   ├── Defines Request/Response models (Pydantic).
│   ├── User roles and permissions.
│   ├── Authentication schemas (LoginRequest, TokenResponse, UserInfo).
│   └── New schemas: LabelSubmission, AnnotationSubmission.
│
├── crypto_utils.py             # 🔒 ENCRYPTION (Optional)
│   └── Utilities for encrypting/decrypting stored images and metadata.
│
├── migrate_storage.py          # 🚚 STORAGE MIGRATION
│   └── Utilities for migrating data between storage formats.
│
├── migrate_users.py            # 🚚 USER MIGRATION
│   └── Utilities for migrating user data and credentials.
│
├── users.json                  # 👥 USER DATABASE
│   └── Stores user credentials with bcrypt-hashed passwords and roles.
│
├── storage/                    # 🗄️ DATABASE (Local File System)
│   ├── <user_id>/              # Per-user directories
│   │   ├── images/             # Saved JPEGs (or encrypted .bin files) from this user.
│   │   ├── metadata.jsonl      # Case logs for this user (one JSON per line).
│   │   └── case_counter.json   # Tracks last used case ID for this user.
│   └── case_counter.json       # Legacy global case counter (backward compatibility).
│
├── requirements.txt            # 📦 DEPENDENCIES
│   └── List of all Python libraries (FastAPI, PyTorch, OpenCV, PyJWT, bcrypt, etc.).
│
└── README_MSSQL.md             # 📚 SQL SERVER DOCUMENTATION
    └── Documentation for MS SQL Server integration (optional).
```

### Key Components Explained

**back.py:**
- Main application entry point
- Defines all REST API endpoints
- Handles CORS, authentication middleware
- Manages case ID generation and user-specific storage

**auth.py:**
- Core authentication logic using JWT (JSON Web Tokens)
- Password hashing and verification with bcrypt
- Token creation with user claims (ID, role, name, expiration)
- Token validation and decoding for protected endpoints

**users.json:**
- JSON file storing user credentials
- Each user has: username (key), password_hash, first_name, last_name, role
- Supports three roles: `gp`, `doctor`, `admin`
- Passwords are hashed with bcrypt for security

**AL.py (Active Learning):**
- Implements margin-based uncertainty sampling
- Identifies cases where the model is uncertain (small difference between top two predictions)
- Helps prioritize which cases need expert review
- Returns top-k most uncertain cases for efficient labeling

**retrain_model.py (Model Retraining):**
- Collects all labeled cases from storage
- Retrains the ResNet50 model using new expert-labeled data
- Supports continuous model improvement
- Tracks retraining status and saves updated model checkpoints

**admin_user_manager.py (User Management CLI):**
- Interactive command-line tool for user administration
- Create new users with secure bcrypt password hashing
- Update user roles (GP, Doctor, Admin)
- List all users and their permissions
- Reset passwords securely

**Per-User Storage:**
- Each user gets their own directory under `storage/`
- Isolates user data for privacy and security
- GPs can only access their own cases; Doctors/Admins can access all

---

## 🛠 Setup & Installation

### 1. Environment Setup
You need **Python 3.9+**. We recommend using a virtual environment (`venv`) to keep your system clean.

```bash
# Navigate to the directory
cd backserver

# Create virtual environment
python -m venv .venv

# Activate it
# macOS/Linux:
source .venv/bin/activate
# Windows:
# .venv\Scripts\activate
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Verify Model Assets
The server expects the trained AI model to be in the shared assets folder:
- **Expected Path:** `../assets/models/ham10000_resnet50_tuned_best.pt`
- *If missing, the server will start in "Dummy Mode" (random/mock predictions).*

### 4. Run the Server
```bash
python -m uvicorn backserver.back:app --host 0.0.0.0 --port 8000
```
The server is now live at: `http://0.0.0.0:8000`

### 5. User Management (Optional)
Use the interactive CLI tool to manage users:
```bash
python -m backserver.admin_user_manager
```

This tool provides:
- **Create User:** Add new users with secure password hashing
- **List Users:** View all users and their roles
- **Update User:** Modify user details and roles
- **Delete User:** Remove users from the system
- **Reset Password:** Securely reset user passwords

---

## 🔐 Authentication & Security

The AllCare Backend uses **JWT (JSON Web Token)** authentication to secure API endpoints and manage user sessions. This provides stateless, scalable authentication suitable for mobile applications.

### JWT Overview

**What is JWT?**
- A compact, URL-safe token format for securely transmitting information between parties
- Contains encoded user claims (user ID, role, name, expiration time)
- Cryptographically signed to prevent tampering
- Stateless - no need to store sessions on the server

### User Roles & Permissions

The system supports three user roles with different access levels:

| Role | Description | Permissions |
| :--- | :--- | :--- |
| `gp` | General Practitioner | Can create cases, view own cases, make image decisions |
| `doctor` | Specialist Doctor | All GP permissions + view all cases, make final diagnoses |
| `admin` | Administrator | Full access to all system features and user data |

### Authentication Flow

1. **Login:** User submits username and password to `/auth/login`
2. **Token Generation:** Server validates credentials and returns a JWT access token
3. **Token Storage:** Mobile app stores the token securely (e.g., Flutter Secure Storage)
4. **API Requests:** App includes token in `Authorization: Bearer <token>` header
5. **Token Validation:** Server verifies token on each request and extracts user context
6. **Token Expiry:** Tokens expire after 24 hours (configurable) - user must re-login

### Login Endpoint

**POST** `/auth/login`

**Request Body:**
```json
{
  "username": "user001",
  "password": "yourpassword"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "user_id": "user001",
    "first_name": "John",
    "last_name": "Doe",
    "role": "doctor"
  }
}
```

**Error Response (401 Unauthorized):**
```json
{
  "detail": "Invalid username or password"
}
```

### Using JWT Tokens in API Requests

After obtaining a token, include it in the `Authorization` header for all protected endpoints:

```bash
# Example: Check image with JWT authentication
curl -X POST "http://localhost:8000/check-image" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "X-API-Key: your-api-key" \
  -F "file=@lesion.jpg"
```

### User Management

Users are stored in `backserver/users.json` with bcrypt-hashed passwords:

```json
{
  "user001": {
    "password_hash": "$2b$12$...",
    "first_name": "John",
    "last_name": "Doe",
    "role": "doctor"
  }
}
```

**Creating New Users:**
Use the provided utility script or manually add entries with bcrypt-hashed passwords.

### Security Features

1. **Password Hashing:** Uses bcrypt with automatic salt generation
2. **Token Expiration:** Configurable expiration (default: 24 hours)
3. **HMAC Signing:** Tokens signed with HS256 algorithm
4. **CORS Protection:** Configurable allowed origins
5. **API Key Support:** Optional additional layer via `X-API-Key` header
6. **HTTPS Support:** Optional TLS/SSL configuration

### Backward Compatibility

The system supports legacy authentication via headers for backward compatibility:
- `X-User-Id`: User identifier
- `X-User-Role`: User role (gp/doctor/admin)

If the `Authorization` header is present, JWT takes precedence over legacy headers.

### Quick Start Example

Here's a complete example of authenticating and making an authenticated request:

**Step 1: Login to get JWT token**
```bash
curl -X POST "http://localhost:8000/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "user001", "password": "yourpassword"}'
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyMDAxIiwicm9sZSI6ImRvY3RvciIsImZpcnN0X25hbWUiOiJKb2huIiwibGFzdF9uYW1lIjoiRG9lIiwiZXhwIjoxNzA5MjU2MDAwLCJpYXQiOjE3MDkxNjk2MDB9.xyz123...",
  "token_type": "bearer",
  "user": {
    "user_id": "user001",
    "first_name": "John",
    "last_name": "Doe",
    "role": "doctor"
  }
}
```

**Step 2: Use the token in subsequent requests**
```bash
# Save the token
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Make an authenticated request
curl -X POST "http://localhost:8000/check-image" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-API-Key: your-api-key" \
  -F "file=@skin_lesion.jpg"
```

**Step 3: Get user's cases**
```bash
curl -X GET "http://localhost:8000/cases?limit=10" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-API-Key: your-api-key"
```

### Token Structure

JWT tokens consist of three parts separated by dots (`.`):
- **Header:** Algorithm and token type
- **Payload:** User claims (user_id, role, name, expiration)
- **Signature:** Cryptographic signature to verify integrity

You can decode the payload (non-sensitive) at [jwt.io](https://jwt.io) to inspect claims, but the signature requires the secret key to verify.

---

## 📡 API Reference

All endpoints (except `/auth/login` and `/health`) require authentication. Use either:
- **JWT Token:** `Authorization: Bearer <token>` (recommended)
- **Legacy Headers:** `X-User-Id` and `X-User-Role` (backward compatibility)

Most endpoints also require an API key if configured: `X-API-Key: your-key`

### Authentication

#### `POST /auth/login`
Authenticate user and receive JWT token.
- **Input:** JSON with `username` and `password`
- **Output:** JSON containing `access_token`, `token_type`, and `user` info
- **Auth Required:** No

### Health Check

#### `GET /health`
Server health check endpoint.
- **Output:** `{"status": "ok"}`
- **Auth Required:** No

### Image Analysis

#### `POST /check-image`
Analyzes a skin lesion image for AI diagnosis.
- **Input:** `multipart/form-data` (key: `file`), optional query param `case_id`
- **Output:** JSON containing `blur_score`, `predictions` (list of classes and confidence), `status`, `image_id`, and `case_id`
- **Auth Required:** Yes
- **Blur Check:** Returns error if image clarity score < threshold

### Case Management

#### `POST /cases/next-id`
Get the next available case ID for the current user.
- **Output:** JSON with `case_id`
- **Auth Required:** Yes

#### `POST /cases/release-id`
Release an unused case ID back to the counter.
- **Input:** JSON with `case_id`
- **Output:** JSON with release status
- **Auth Required:** Yes

#### `GET /cases`
Fetch case history.
- **Params:**
  - `limit` (int, default: 100) - Maximum number of cases to return
  - `status` (string, optional) - Filter by case status
  - `include_uncertain` (bool, default: true) - Include uncertain cases
  - `include_rejected` (bool, default: true) - Include rejected cases
- **Output:** JSON list of past cases (most recent first)
- **Auth Required:** Yes
- **Access:** GPs see only their cases; Doctors/Admins see all cases

#### `POST /cases`
Save a confirmed case diagnosis.
- **Input:** JSON matching `CaseLog` schema (see `schemas.py`)
- **Output:** JSON with `status`, `message`, `case_id`, and `case_status`
- **Auth Required:** Yes

#### `PUT /cases/{case_id}`
Update an existing case.
- **Input:** JSON with fields to update (see `CaseUpdate` schema)
- **Output:** JSON with `status` and `case_id`
- **Auth Required:** Yes
- **Access:** GPs can update own cases; Doctors/Admins can update any case

#### `POST /cases/uncertain`
Log a case marked as uncertain (requires specialist review).
- **Input:** JSON matching `CaseLog` schema
- **Output:** JSON with `status`, `message`, `case_id`, and `case_status`
- **Auth Required:** Yes

#### `POST /cases/reject`
Reject a case (e.g., poor image quality, non-skin issue).
- **Input:** JSON matching `RejectCase` schema (includes `reason`)
- **Output:** JSON with `status` and `message`
- **Auth Required:** Yes

### Labeling & Annotations

#### `POST /cases/{case_id}/label`
Submit correct label for a case (used for model retraining).
- **Input:** JSON matching `LabelSubmission` schema (contains `correct_label` and optional `notes`)
- **Output:** JSON with `status` and confirmation message
- **Auth Required:** Yes
- **Purpose:** Provides ground truth labels for model improvement

#### `POST /cases/{case_id}/annotations`
Submit manual annotations (strokes, bounding boxes) for a case.
- **Input:** JSON matching `AnnotationSubmission` schema (contains `image_index`, `correct_label`, `annotations`, etc.)
- **Output:** JSON with `status` and confirmation message
- **Auth Required:** Yes
- **Purpose:** Collects detailed annotations for fine-grained model training

### Active Learning

#### `POST /active-learning/candidates`
Get list of uncertain cases that need expert review.
- **Input:** JSON with optional `top_k` parameter (default: 5)
- **Output:** JSON containing:
  - `candidates`: List of cases with uncertainty scores
  - `total_candidates`: Number of candidates returned
  - `selection_method`: "minimum_margin_case_sampling"
  - `description`: Explanation of selection criteria
- **Auth Required:** Yes
- **Algorithm:** Uses margin-based uncertainty sampling (difference between top two predictions)

### Model Management

#### `GET /model/retrain-status`
Check the status of model retraining.
- **Output:** JSON containing:
  - `status`: "not_started", "in_progress", "completed", or "error"
  - `last_retrain`: Timestamp of last retraining (if any)
  - `message`: Additional status information
- **Auth Required:** Yes

#### `POST /model/retrain`
Trigger model retraining with labeled cases.
- **Input:** Optional JSON with `epochs` (default: 5) and `batch_size` (default: 16)
- **Output:** JSON with `status` and process information
- **Auth Required:** Yes
- **Requirements:** At least 5 labeled cases in storage
- **Note:** This is a long-running operation; use `/model/retrain-status` to check progress

---

## ⚙️ Configuration (`config.py`)

You can adjust these settings by editing `config.py` or setting Environment Variables.

### Core Settings

| Variable | Default | Meaning |
| :--- | :--- | :--- |
| `BACKSERVER_HOST` | `0.0.0.0` | Listen on all network interfaces. |
| `BACKSERVER_PORT` | `8000` | Port number for the server. |
| `MODEL_PATH` | `../assets/models/ham10000_resnet50_tuned_best.pt` | Path to the AI model file. |
| `MODEL_DEVICE` | `auto` | Set to `cpu`, `cuda`, or `mps` to force specific hardware. |
| `BLUR_THRESHOLD` | `100.0` | Lower values allow blurrier images. Higher values are stricter. |
| `CONF_THRESHOLD` | `0.5` | Minimum confidence to consider a prediction "valid" (UI logic). |

### Authentication & Security

| Variable | Default | Meaning |
| :--- | :--- | :--- |
| `JWT_SECRET_KEY` | `your-secret-key-change-in-production` | **CRITICAL:** Secret key for signing JWT tokens. **MUST** change in production! |
| `JWT_ALGORITHM` | `HS256` | Algorithm used for JWT signing (HS256, HS384, or HS512). |
| `JWT_EXPIRATION_HOURS` | `24` | Token expiration time in hours. |
| `API_KEY` | `` | Optional API key for additional security layer. Required in all requests if set. |
| `ALLOWED_ORIGINS` | `*` | Comma-separated list of allowed CORS origins (e.g., `https://app.example.com`). |
| `USERS_FILE` | `backserver/users.json` | Path to user credentials database file. |

### Data Storage & Encryption

| Variable | Default | Meaning |
| :--- | :--- | :--- |
| `STORAGE_ROOT` | `backserver/storage` | Root directory for storing images and metadata. |
| `ENCRYPT_STORAGE` | `` | Set to `true` to encrypt stored images and metadata. |
| `DATA_ENCRYPTION_KEY` | `` | URL-safe base64 key (16/24/32 bytes) used for storage encryption. |
| `CASE_ID_START` | `10000` | Starting number for case IDs. |

### TLS/HTTPS Configuration

| Variable | Default | Meaning |
| :--- | :--- | :--- |
| `TLS_CERT_FILE` | `` | Path to TLS certificate for HTTPS (uvicorn). |
| `TLS_KEY_FILE` | `` | Path to TLS private key for HTTPS (uvicorn). |

### Important Notes

- **JWT_SECRET_KEY:** This is the most critical security setting. Generate a strong random key for production:
  ```bash
  python -c "import secrets; print(secrets.token_urlsafe(32))"
  ```
- **ENCRYPT_STORAGE:** When enabled, images are saved as encrypted `.bin` files and each metadata line is stored as an encrypted JSON wrapper. Keep `DATA_ENCRYPTION_KEY` secure and available to read existing data.
- **TLS/HTTPS:** For production deployments, enable HTTPS by setting `TLS_CERT_FILE` and `TLS_KEY_FILE`, or use a reverse proxy (nginx, Apache) with SSL termination.
- **API_KEY:** Adds an extra layer of protection. Set this in production and include `X-API-Key` header in all client requests.

---

## 🧠 AI Model Details

We use a **ResNet50** architecture (a standard Deep Learning model for image recognition), fine-tuned on the **HAM10000** dataset.

**Classes it detects:**
1.  **akiec**: Actinic keratoses (Pre-cancerous)
2.  **bcc**: Basal cell carcinoma (Cancer)
3.  **bkl**: Benign keratosis (Benign)
4.  **df**: Dermatofibroma (Benign)
5.  **mel**: Melanoma (Dangerous Cancer)
6.  **nv**: Melanocytic nevi (Moles - Benign)
7.  **vasc**: Vascular lesions (Benign)

---

## 🛠 Troubleshooting

### General Issues

**Problem: "ModuleNotFoundError: No module named 'fastapi'" or missing dependencies**
> **Fix:** You forgot to install dependencies. Run `pip install -r requirements.txt` in your virtual environment.

**Problem: "The system cannot find the path specified" (Model load error)**
> **Fix:** Check if the model file exists at `assets/models/ham10000_resnet50_tuned_best.pt`. If you are running the script from a different directory, the relative path might be wrong. Use absolute paths in `MODEL_PATH` environment variable if needed.

**Problem: App cannot connect to Localhost**
> **Fix:** Android Emulators cannot see `localhost`. Use `10.0.2.2` instead of `127.0.0.1`.
> - **Wrong:** `http://127.0.0.1:8000/check-image`
> - **Right:** `http://10.0.2.2:8000/check-image`

### Authentication & JWT Issues

**Problem: "Invalid username or password" when credentials are correct**
> **Fix:**
> - Ensure `users.json` exists and is properly formatted
> - Verify the password hash was generated with bcrypt
> - Check file permissions on `users.json`
> - Try regenerating the password hash

**Problem: "Token has expired" error**
> **Fix:** The JWT token has exceeded its expiration time (default: 24 hours). The user must log in again to get a new token. Consider increasing `JWT_EXPIRATION_HOURS` if needed.

**Problem: "Invalid token" or "Invalid Authorization header format"**
> **Fix:**
> - Ensure the Authorization header format is: `Authorization: Bearer <token>`
> - Check that the token wasn't modified or truncated
> - Verify `JWT_SECRET_KEY` hasn't changed since token was issued
> - Ensure there's a space between "Bearer" and the token

**Problem: "Missing Authorization header or X-User-Id header"**
> **Fix:** You must provide either:
> - JWT authentication: `Authorization: Bearer <token>` header
> - OR legacy authentication: `X-User-Id` and `X-User-Role` headers

**Problem: Cannot create/modify users in users.json**
> **Fix:** Use this Python script to create a user with a hashed password:
> ```python
> import bcrypt
> import json
>
> password = "yourpassword"
> hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
>
> user = {
>     "username": {
>         "password_hash": hashed,
>         "first_name": "John",
>         "last_name": "Doe",
>         "role": "doctor"
>     }
> }
> print(json.dumps(user, indent=2))
> ```

**Problem: "Invalid API key" error**
> **Fix:**
> - Ensure the `X-API-Key` header is included in requests
> - Verify the API key matches the `API_KEY` environment variable
> - If no API key is needed, ensure `API_KEY` is unset or empty

### Data & Storage Issues

**Problem: Cases not showing up for a user**
> **Fix:**
> - Check that the user is authenticated correctly (user_id matches)
> - GPs can only see their own cases - verify user role
> - Check `storage/<user_id>/metadata.jsonl` exists and has data
> - For admins/doctors: verify global access is working

**Problem: Encryption errors when reading data**
> **Fix:**
> - Ensure `DATA_ENCRYPTION_KEY` is set correctly
> - The same encryption key must be used to read encrypted data
> - If you changed the key, previously encrypted data cannot be decrypted
> - Don't enable/disable `ENCRYPT_STORAGE` with existing data without migration
