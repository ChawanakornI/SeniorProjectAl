# Frontend-Backend Integration Walkthrough

This document summarizes the complete integration between the Flutter mobile app and the FastAPI backend for the skin lesion classification system.

---

## Overview

The integration enables dynamic data flow between the mobile app and backend server for:

- ✅ Creating and logging case records
- ✅ Fetching and displaying cases across all pages
- ✅ Storing ML predictions with case metadata
- ✅ Image path persistence for case review

---

## Architecture

```
┌─────────────────┐         HTTP          ┌──────────────────┐
│   Flutter App   │ ◄──────────────────►  │  FastAPI Backend │
└─────────────────┘                       └──────────────────┘
                                                   │
                                    ┌──────────────┼──────────────┐
                                    ▼              ▼              ▼
                            ┌────────────┐  ┌──────────┐  ┌──────────────┐
                            │ ML Model   │  │ metadata │  │    Images    │
                            │ (PyTorch)  │  │ .jsonl   │  │ (storage/)   │
                            └────────────┘  └──────────┘  └──────────────┘
```

---

## Backend Changes

### 📁 `backserver/schemas.py`

Added `image_paths` field to `CaseLog` model:

```python
class CaseLog(BaseModel):
    case_id: str
    image_id: Optional[str] = None
    predictions: List[Prediction] = Field(default_factory=list)
    status: str = "pending"
    gender: Optional[str] = None
    age: Optional[str] = None
    location: Optional[str] = None
    symptoms: List[str] = Field(default_factory=list)
    image_paths: List[str] = Field(default_factory=list)  # ← NEW
    created_at: Optional[str] = None
```

---

### 📁 `backserver/back.py`

Added `GET /cases` endpoint for fetching all cases:

```python
@app.get("/cases")
async def get_cases(status: Optional[str] = None, limit: int = 100):
    # Reads from metadata.jsonl and returns case records
```

---

## Frontend Changes

### 🆕 New Files

#### `lib/features/case/case_service.dart`

Central service for case CRUD operations:

| Method         | Purpose                                             |
| -------------- | --------------------------------------------------- |
| `fetchCases()` | GET all cases from backend                          |
| `logCase()`    | POST new case with status, predictions, image paths |
| `rejectCase()` | POST rejected case                                  |

**CaseRecord Model** parses backend JSON with fields:

- `caseId`, `status`, `predictions`
- `gender`, `age`, `location`, `symptoms`
- `imagePaths`, `createdAt`

---

### 📝 Modified Pages

#### `lib/pages/home_page.dart`

| Feature             | Implementation                                                  |
| ------------------- | --------------------------------------------------------------- |
| **Dynamic data**    | Calls `CaseService().fetchCases()` in `initState`               |
| **Date filter**     | `_filteredCaseRecords` filters by `_selectedDate` from calendar |
| **Pull-to-refresh** | `RefreshIndicator` wraps case list                              |
| **Case click**      | `GestureDetector` navigates to `CaseSummaryScreen`              |

---

#### `lib/pages/notification_page.dart`

| Feature             | Implementation                                 |
| ------------------- | ---------------------------------------------- |
| **Dynamic data**    | Fetches cases on init                          |
| **Filter tabs**     | All / New cases (Confirmed) / Pending labeling |
| **Clickable items** | Navigate to `CaseSummaryScreen` on tap         |
| **Clear button**    | Header button to clear notification list       |

---

#### `lib/pages/dashboard_page.dart`

| Feature                    | Implementation                                  |
| -------------------------- | ----------------------------------------------- |
| **Real stats**             | Computes Total/Pending/Confirmed from `_cases`  |
| **Case trend**             | Shows actual case count (not hardcoded)         |
| **Diagnosis distribution** | Groups cases by `topPredictionLabel`            |
| **Recent activity**        | Clickable items navigate to `CaseSummaryScreen` |

---

#### `lib/features/case/result_screen.dart`

| Feature            | Implementation                                        |
| ------------------ | ----------------------------------------------------- |
| **Confirm button** | Calls `logCase(status: 'Confirmed', imagePaths: ...)` |
| **Pending button** | Calls `logCase(status: 'pending', imagePaths: ...)`   |
| **Reject button**  | Calls `rejectCase()`                                  |

---

## Data Flow

### 1️⃣ Case Creation Flow

```
NewCaseScreen
      │
      ▼
PhotoPreviewScreen  →  CaseSummaryScreen
                             │
                             ▼
                       Run Prediction
                             │
                             ▼
                       ResultScreen
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
          Confirm        Pending        Reject
              │              │              │
              └──────────────┼──────────────┘
                             ▼
                   logCase() → Backend
```

---

### 2️⃣ Case Display Flow

```
Backend (metadata.jsonl)
              │
              ▼
       GET /cases endpoint
              │
              ▼
   CaseService.fetchCases()
              │
    ┌─────────┼─────────┐
    ▼         ▼         ▼
HomePage  Notification  Dashboard
            Page         Page
```

---

### 3️⃣ Case Review Flow

```
Case Record Item
(HomePage / NotificationPage / DashboardPage)
              │
              ▼ Tap
       Navigator.push()
              │
              ▼
    CaseSummaryScreen
    (with predictions, images)
```

---

## Running the Application

### 🖥️ Backend

```bash
cd /path/to/AllCare
python -m uvicorn backserver.back:app --host 0.0.0.0 --port 8000
```

### 📱 Flutter App

```bash
cd /path/to/Always
flutter run --dart-define=BACKSERVER_BASE=http://<YOUR_IP>:8000
```

> ⚠️ **Important:** Replace `<YOUR_IP>` with your computer's local IP address (e.g., `192.168.1.119`).
>
> - **Android Emulator:** Use `http://10.0.2.2:8000`
> - **iOS Simulator:** Use `http://127.0.0.1:8000`

---

## Summary

| Component                                  | Status |
| ------------------------------------------ | :----: |
| Backend `/cases` endpoint                  |   ✅   |
| `CaseService` with `fetchCases`, `logCase` |   ✅   |
| HomePage backend integration               |   ✅   |
| NotificationPage backend integration       |   ✅   |
| DashboardPage backend integration          |   ✅   |
| Calendar date filtering                    |   ✅   |
| Case click navigation                      |   ✅   |
| Image path persistence                     |   ✅   |
| Clear notifications                        |   ✅   |
