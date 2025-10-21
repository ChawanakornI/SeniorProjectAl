# Skin Disease Decision Support System Requirements

## 1. Product Vision
This project delivers an AI-assisted decision support platform that helps doctors in rural clinics diagnose and manage skin disease cases. The system combines structured patient data, standardized images, and a prediction model so doctors can confirm, reject, or escalate suggested diagnoses while keeping specialists in the loop.

## 2. Stakeholders and Roles
- **Doctor:** Primary user who creates cases, captures visit data, reviews predictions, makes clinical decisions, annotates rejected cases, and monitors personal workload.
- **Specialist:** Secondary reviewer who receives cases marked as uncertain and returns guidance that updates the case history.
- **System Services:** Background processes that validate images, execute predictions, store data, raise notifications, and surface analytics.

## 3. End-to-End Workflow
1. Doctor signs in to the application.
2. Doctor creates or retrieves a patient case using the hospital number (HN).
3. Doctor records visit metadata, selects affected body areas, and uploads standardized images.
4. The system validates images and runs the prediction model to produce candidate diagnoses with confidence scores.
5. Doctor either confirms the diagnosis, rejects it and annotates the images, or marks the case as uncertain for specialist review.
6. The system tracks status changes, reminds the doctor about pending actions, and updates dashboards and performance metrics.

## 4. Functional Requirements
### 4.1 Authentication and Access Control
- Doctors must authenticate before accessing any patient data or tools.
- The system must support secure session management and profile updates for each doctor.

### 4.2 Case Intake and Patient Lookup
- The home page prioritizes case creation.
- Doctors enter an HN to search for existing patients.
- When the HN exists, the system fetches stored patient details and proceeds directly to visit metadata entry.
- If the HN is missing, the system prompts for first-visit metadata (demographics, baseline history) before continuing to visit metadata.
- Each new patient record receives a unique HN.

### 4.3 Visit Data Capture
- Doctors record presenting illness descriptions, visit timestamps, and relevant history.
- A body diagram (front and back) is available to highlight affected regions and add textual notes for specific areas.
- Doctors may attach multiple images per visit, and the system enforces completion of required fields before submission.

### 4.4 Image Handling Standards
- The system performs automatic checks for blur, orientation, lighting, and required resolution.
- Doctors can review each image, accept it, or retake and replace it before prediction runs.
- All accepted images are standardized for model input and stored with the visit record.

### 4.5 AI Prediction and Decision Support
- After data submission, the system launches the AI model and returns the top predicted disease with a confidence value.
- Predictions are displayed alongside supporting imagery so the doctor can validate them.
- If the prediction service is temporarily unavailable, the case is queued and processed once the service recovers.

### 4.6 Doctor Decision Pathways
- **Confirm:** The case is stored as confirmed, and no further action is required.
- **Reject:** The system opens the annotation workflow so the doctor can specify the correct diagnosis and mark lesion boundaries.
- **Uncertain:** The system packages the case for specialist review and records the pending referral.
- Doctors may revisit a decision before final submission when needed.

### 4.7 Annotation and Active Learning
- The annotation workspace includes bounding box, polygon, and freehand tools.
- Doctors provide the correct diagnosis label when annotating.
- Completed annotations are saved as labeled data for future model retraining.
- Incomplete annotations remain in a pending state, and the system issues reminders until the doctor finishes or cancels them.

### 4.8 Specialist Referral Workflow
- When a case is marked uncertain, the system forwards the relevant data set to the specialist queue.
- Specialists review the case, record feedback or a final diagnosis, and the doctor receives a notification when the response arrives.
- If no specialist is available, the case stays pending and the doctor is informed.

### 4.9 Case Management and Editing
- Every case carries a status: Confirmed, Rejected – Annotated, Rejected – Pending Annotation, or Uncertain.
- Doctors can edit patient and visit information when corrections are needed, with audit trails for any changes.
- Cases can be filtered by status, patient, and date range to simplify follow-up work.

### 4.10 Dashboard and Reporting
- The dashboard surfaces totals by day, week, and month; status distribution; most frequent predicted diseases; outstanding annotations; specialist referrals; and model confidence trends.
- Filters allow drills by patient, status, and timeframe, and visualizations provide quick insight into workload and model performance.

### 4.11 Notifications and Alerts
- The system alerts doctors to pending annotations, specialist responses, and new model versions following retraining.
- Notification history is retained so doctors can track unresolved tasks.

### 4.12 System Automation Services
- Image validation runs automatically as soon as files are uploaded.
- Data is standardized and stored with versioned case records.
- Prediction requests are queued and retried when service interruptions occur.
- Annotated data feeds the training pipeline for future model improvements.

## 5. Detailed Use Cases
- **UC-001 – Doctor Login:** Doctor enters credentials, the system validates them, and successful login redirects to the dashboard. Invalid credentials trigger an error; locked accounts require administrator support; forgotten passwords use a reset workflow.
- **UC-002 – Create Case and HN Check:** Doctor inputs an HN. The system retrieves the patient record if it exists; otherwise, it guides the doctor through new patient registration and generates a new HN. Duplicate HNs are rejected.
- **UC-003 – Visit Data Entry:** After locating or creating a patient, the doctor completes visit metadata. Required fields are validated, and network interruptions trigger retries or local drafts.
- **UC-004 – AI Prediction:** Upon visit submission the system executes the prediction model and returns ranked diagnoses with confidence scores. Partial data prompts correction before the model runs.
- **UC-005 – Doctor Decision:** Doctor reviews the prediction and selects confirm, reject, or uncertain. Each selection routes the case to the appropriate follow-up step.
- **UC-006 – Annotation Workflow:** Triggered by a rejection. The doctor annotates lesion regions, supplies the correct diagnosis, and saves the annotated case. Corrupted images must be replaced before completion.
- **UC-007 – Specialist Referral:** Triggered by an uncertain decision. The case is queued for specialist review, and the doctor receives the outcome once it is recorded. Network issues create a pending referral that is retried automatically.
- **UC-008 – Dashboard and Metrics:** Doctor opens the dashboard to review workload and model metrics. If data is unavailable, the system shows an empty state and guidance to create the first case.
- **UC-009 – Case History:** Doctor searches historical cases, filters results, and opens details to review predictions, annotations, and outcomes. Empty results display a clear message.
- **UC-010 – Logout:** Doctor ends the session. The system clears tokens and returns to the login page. Expired sessions trigger an automatic redirect to login.

## 6. Rural Healthcare Impact
- Improves diagnostic support for clinics without on-site dermatologists.
- Reduces unnecessary referrals by giving doctors higher confidence in their decisions.
- Builds a continually improving model through active learning from real cases.
- Delivers faster, more equitable care for patients in underserved regions.
