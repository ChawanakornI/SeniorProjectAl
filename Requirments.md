# 🩺 Skin Disease Detection & Annotation System

This project is a **decision support system** designed to help **rural doctors** detect and manage skin disease cases using **AI-assisted predictions** with **active learning feedback**.  

Doctors can confirm, reject, or mark uncertain predictions, while rejected cases trigger an **annotation workflow** to improve the model.

---

## 1. Introduction and General Description

This system collects **first visit metadata** (patient demographics) and **visit metadata** (illness details, affected body area, and standardized images).  

Doctors create a **case** for each patient visit:

- **HN check workflow (Not Sure):**  
  - If the patient already exists (with HN) → system only asks for **Visit Metadata**.  
  - If the patient is new (no HN) → system asks for **First Visit Metadata** first, then continues to **Visit Metadata**.  

**Doctor Features:**  
- Login to the system securely.  
- Edit any existing patient or visit information.  
- Manage their profile and view assigned tasks/cases.  

The AI model predicts the most likely disease, and the doctor can:
- **Confirm** → accept the AI prediction.  
- **Reject** → annotate images for retraining.  
- **Uncertain** → forward the case to a specialist.  

The system also provides a **dashboard** for monitoring cases, pending tasks, and overall performance.  

👉 The role of the doctor is to use AI as a **support tool**, not a replacement for diagnosis.  
👉 Specialists remain involved when uncertainty arises.  
👉 The system maintains a complete history of cases (confirmed, rejected, uncertain, annotated).

---

## 2. General Requirements

- Doctors must **log in** to the system. **(Not Sure: authentication method TBD)**  
- Doctors start at **Home Page → Create Case**. **(Not Sure: exact flow may change)**  
- System must check if patient has **HN (Hospital Number)**. **(Not Sure)**  
  - If HN exists → go directly to **Visit Metadata** entry. **(Not Sure)**  
  - If HN does not exist → system prompts doctor to enter **First Visit Metadata**, then continues to **Visit Metadata**. **(Not Sure)**  
- Doctors can **edit patient information** (first visit metadata, visit metadata).  
- Provide a **body diagram (front/back)** to select affected areas.  
- Validate image quality (blur, lighting, standardization).  
- Provide **AI predictions** with confidence scores.  
- Allow doctors to:
  - Confirm predictions.  
  - Reject predictions and annotate.  
  - Mark as uncertain and forward to a specialist.  
- Store annotated cases for **future retraining**.  
- Notify doctors about **pending unlabeled cases**.  
- Provide a **dashboard** summarizing case statistics, model performance, and pending tasks.

---

## 3. Specific Requirements

### 3.1 Doctor Account & Authentication
- Doctors must **log in** before accessing the system. **(Not Sure: authentication workflow TBD)**  
- Doctors can **edit their own profile**.  
- Doctors can **edit patient and visit data**, if necessary. **(Not Sure: editing restrictions TBD)**  

### 3.2 Case Creation & Data Management  
- **Patient Entry (Not Sure):**  
  - Enter **HN**.  
  - If HN exists → fetch patient info → proceed to **Visit Metadata**.  
  - If HN not found → enter **First Visit Metadata** → proceed to **Visit Metadata**.  

- **Visit Metadata**  
  - Present illness description.  
  - Visit date/time.  
  - Affected position (front/back body diagram).  
  - Specific area text input.  
  - Captured images.  

### 3.3 Image Handling  
- Validate images (blur, standard format).  
- Allow multiple images per visit.  
- Doctor must confirm images before prediction.  

### 3.4 Prediction  
- Show top-1 predicted disease.  
- Show confidence percentage.  
- Display predicted image for doctor verification.  

### 3.5 Case Decision  
- **Confirm →** store as confirmed case.  
- **Reject →** open annotation page.  
- **Uncertain →** forward case to specialist.  

### 3.6 Annotation Workflow  
- Provide annotation tools (bounding box, polygon, freehand).  
- Doctors can confirm annotation (case stored as labeled for retraining).  
- Doctors can cancel annotation (case stored as pending, reminder shown in home page).  

### 3.7 Case Management  
- Each case must have a **status**: Confirmed, Rejected → Annotated, Rejected → Pending, Uncertain.  
- Doctor can **edit case information**. **(Not Sure: editing permissions TBD)**  
- Doctor can filter cases by **status, date, or patient**.  

### 3.8 Dashboard  
- Show statistics:
  - Total cases handled (day/week/month).  
  - Distribution by status (Confirmed, Rejected, Uncertain).  
  - Top predicted diseases.  
  - Pending annotation tasks.  
  - Specialist referral counts.  
  - Model performance (avg. confidence, confirmed accuracy).  
- Support filters by **date, patient, or status**.  

### 3.9 Notifications  
- Notify doctor of pending annotations.  
- Notify doctor of specialist replies.  
- Notify doctor of new model updates (after retraining).  

---

## 4. Commands  

### Doctor Commands  
- **Login** (access system securely). **(Not Sure: auth method TBD)**  
- **Create Case** (enter HN → new or existing patient) **(Not Sure: exact HN check flow)**  
- Enter **First Visit Metadata** (only if no HN). **(Not Sure)**  
- Enter **Visit Metadata**.  
- Capture Image (validate blur/quality, confirm or retake).  
- View Prediction (disease + confidence).  
- Confirm Prediction (store as confirmed case).  
- Reject Prediction (open annotation page).  
- Annotate Image (draw/label tools, confirm/cancel).  
- Mark Uncertain (send to specialist).  
- **Edit Patient / Visit Data** **(Not Sure: editing rules TBD)**  
- View Dashboard (statistics, filters).  
- View Case History (filterable list of past cases).  

### System Commands  
- Validate Image Quality (blur, size, orientation, lighting).  
- Standardize Image for model input.  
- Run Prediction Model and return top-1 disease.  
- Store Case Data with status updates.  
- Notify Pending Cases to doctor.  
- Update Dashboard Data in real-time.  
- Send Uncertain Cases to specialist.  
- Save Annotated Images into labeled dataset for retraining.  

---

## 🌍 Why This Matters for Rural Doctors

- **Accessibility:** Supports doctors without nearby specialists.  
- **Efficiency:** Reduces unnecessary referrals.  
- **Learning System:** Rejected/annotated cases improve the AI model over time.  
- **Decision Support:** AI assists but does not replace doctors.  
- **Patient Benefit:** Faster diagnosis, better resource use, improved healthcare equity.  
