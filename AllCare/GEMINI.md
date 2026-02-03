# Alskin - Skin Cancer Detection (Senior Project)

## Project Overview
**Alskin** is a cross-platform application (Flutter) paired with a backend server (FastAPI) designed for AI-assisted skin lesion triage. It supports role-based workflows for General Practitioners (GPs) and Doctors, allowing them to capture lesion images, run AI inference for diagnosis, and manage patient cases.

## Architecture
The system consists of two main components:
1.  **Frontend (Flutter):** A mobile application offering role-specific interfaces (GP vs. Doctor), camera integration for image capture, and glassmorphism-styled UI. It communicates with the backend via REST APIs.
2.  **Backend (FastAPI):** A Python-based server that handles image processing (blur detection), AI inference (using PyTorch models), and case data persistence (JSONL logging).

## Key Directories

### Root
- **`assets/`**: Contains static resources like images (`images/`), mock credentials (`mock_credentials.csv`), and PyTorch models (`models/`).
- **`lib/`**: Flutter source code.
- **`backserver/`**: Python backend source code.

### Frontend (`lib/`)
- **`main.dart`**: Entry point. Initializes the app and camera.
- **`app_state.dart`**: A global singleton (`appState`) extending `ChangeNotifier` for simple state management (User role, Theme, Language).
- **`routes.dart`**: Centralized route definitions.
- **`pages/`**: Screen widgets (e.g., `home_page.dart` for doctors, `gp_home_page.dart` for GPs).
- **`features/case/`**: Logic and UI for the core case management workflow (Camera, API services, Result screens).

### Backend (`backserver/`)
- **`back.py`**: The FastAPI application entry point and route definitions (`/check-image`, `/cases`, etc.).
- **`model.py`**: Handles loading PyTorch models and running inference.
- **`config.py`**: Configuration management via environment variables.
- **`storage/`**: Directory where uploaded images and `metadata.jsonl` logs are stored.

## Building and Running

### Backend
1.  Navigate to the backend directory:
    ```bash
    cd backserver
    ```
2.  Create and activate a virtual environment (optional but recommended):
    ```bash
    python -m venv .venv
    source .venv/bin/activate  # macOS/Linux
    ```
3.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
4.  Start the server:
    ```bash
    python back.py
    # Or using uvicorn directly:
    # uvicorn back:app --reload
    ```
    *Defaults to `http://0.0.0.0:8000`.*

### Frontend
1.  Ensure the backend is running.
2.  Install Flutter dependencies:
    ```bash
    flutter pub get
    ```
3.  Run the app, pointing to the backend URL:
    ```bash
    flutter run --dart-define=BACKSERVER_BASE=http://10.0.2.2:8000
    ```
    *Note: Use `http://10.0.2.2:8000` for Android Emulator, `http://127.0.0.1:8000` for iOS Simulator.*

## Development Conventions

### Frontend (Flutter)
- **State Management:** Uses a simple global `AppState` (ChangeNotifier) for app-wide settings.
- **Networking:** `http` package used in `features/case/` services (`case_service.dart`, `prediction_service.dart`).
- **UI:** Heavily relies on "Glassmorphism" styling (`theme/glass.dart`) and `flutter_neumorphic_plus`.
- **Roles:** The app logic switches significantly based on the user role (GP vs. Doctor), often routing to entirely different home screens.

### Backend (Python)
- **Framework:** FastAPI with Pydantic models for validation (`schemas.py`).
- **Persistence:** Lightweight file-based persistence. Images are saved as JPEGs, and metadata is appended to a `metadata.jsonl` file.
- **ML/AI:** Uses PyTorch (`torch`, `torchvision`) for model inference and OpenCV (`cv2`) for blur detection.

## Key Files
- `README.md`: Comprehensive documentation and manual.
- `pubspec.yaml`: Flutter dependencies.
- `lib/main.dart`: App initialization.
- `backserver/back.py`: Backend API implementation.
- `backserver/requirements.txt`: Python dependencies.
