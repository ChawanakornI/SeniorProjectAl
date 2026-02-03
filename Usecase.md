# SeniorProjectAl
| **Use Case Name:** | Doctor Login |
|--------------------|--------------|
| **ID:** | UC-001 |
| **Importance Level:** | High |
| **Primary Actor:** | Doctor |
| **Use Case Type:** | Essential Business Process |
| **Stakeholders and Interests:** | **Doctor:** Needs secure access to system.<br> **System:** Must authenticate users correctly. |
| **Brief Description:** | Doctor logs into the system with valid credentials to access patient cases and AI predictions. |
| **Trigger:** | Doctor enters username and password on login page. |
| **Relationships:** | None |
| **Normal Flow of Events (including subflows):** | 1. Doctor opens system login page.<br> 2. Doctor enters credentials.<br> 3. System validates credentials.<br> 4. If valid → Doctor is redirected to dashboard. |
| **Alternate/Exceptional Flow:** | - If credentials invalid → system shows error.<br> - If account locked → contact admin.<br> - If forgotten password → go to password reset. |
| **Note:** | Secure login required before any other use case. |
---

| **Use Case Name:** | Create Case <br>(HN Check & Patient Registration) |
|--------------------|--------------------------------------------------|
| **ID:** | UC-002 |
| **Importance Level:** | High |
| **Primary Actor:** | Doctor |
| **Use Case Type:** | Essential Business Process |
| **Stakeholders and Interests:** | **Doctor:** Needs to register or find patient.<br> **System:** Must verify HN or create new record. |
| **Brief Description:** | Doctor searches existing HN. If found, system loads patient data. If not found, system creates a new patient record with unique HN. |
| **Trigger:** | Doctor initiates new case creation. |
| **Relationships:** | Includes: Visit Data Entry |
| **Normal Flow of Events (including subflows):** | 1. Doctor enters HN.<br> 2. System checks database.<br> 3. If found → load patient profile.<br> 4. If not found → prompt registration.<br> 5. System generates new HN. |
| **Alternate/Exceptional Flow:** | - Invalid HN → system shows error.<br> - Duplicate HN → system rejects and prompts correction. |
| **Note:** | Each patient must have a unique HN. |
---

| **Use Case Name:** | Visit Data Entry |
|--------------------|------------------|
| **ID:** | UC-003 |
| **Importance Level:** | High |
| **Primary Actor:** | Doctor |
| **Use Case Type:** | Essential Business Process |
| **Stakeholders and Interests:** | **Doctor:** Needs to input case details.<br> **System:** Must store data for AI prediction. |
| **Brief Description:** | Doctor records patient symptoms, history, and clinical information for the visit. |
| **Trigger:** | After creating or retrieving patient case. |
| **Relationships:** | Extends: Create Case |
| **Normal Flow of Events (including subflows):** | 1. Doctor opens visit form.<br> 2. Inputs symptoms, history, vital signs.<br> 3. System validates required fields.<br> 4. Data saved successfully. |
| **Alternate/Exceptional Flow:** | - If mandatory fields missing → system shows alert.<br> - If network issue → system retries or saves offline. |
| **Note:** | This data feeds directly into AI prediction. |
---

| **Use Case Name:** | AI Prediction |
|--------------------|---------------|
| **ID:** | UC-004 |
| **Importance Level:** | High |
| **Primary Actor:** | System |
| **Use Case Type:** | Essential Business Process |
| **Stakeholders and Interests:** | **Doctor:** Needs prediction support.<br> **System:** Must process input and generate results. |
| **Brief Description:** | The system analyzes visit data and generates a disease prediction with confidence level. |
| **Trigger:** | After Visit Data Entry is submitted. |
| **Relationships:** | Precedes: Doctor Decision |
| **Normal Flow of Events (including subflows):** | 1. Doctor submits case data.<br> 2. System runs AI model.<br> 3. System returns disease prediction with probability scores.<br> 4. Prediction displayed on doctor dashboard. |
| **Alternate/Exceptional Flow:** | - If AI service unavailable → system queues request.<br> - If data incomplete → system prompts correction. |
| **Note:** | Predictions are advisory, final decision belongs to doctor. |
---

| **Use Case Name:** | Doctor Decision (Confirm / Reject / Uncertain) |
|--------------------|-----------------------------------------------|
| **ID:** | UC-005 |
| **Importance Level:** | High |
| **Primary Actor:** | Doctor |
| **Use Case Type:** | Essential Business Process |
| **Stakeholders and Interests:** | **Doctor:** Needs to finalize AI prediction results.<br> **System:** Must record the decision outcome. |
| **Brief Description:** | The doctor reviews the AI prediction and decides to Confirm, Reject, or mark as Uncertain. |
| **Trigger:** | After AI prediction is displayed. |
| **Relationships:** | Includes: Annotation Workflow (if Rejected)<br> Includes: Specialist Referral (if Uncertain) |
| **Normal Flow of Events (including subflows):** | 1. Doctor views prediction.<br> 2. Doctor selects:<br> - Confirm → case stored as Confirmed.<br> - Reject → system opens Annotation Workflow.<br> - Uncertain → system forwards case to specialist. |
| **Alternate/Exceptional Flow:** | - If network error prevents referral, case is queued.<br> - If doctor cancels decision, system returns to prediction page. |
| **Note:** | Each case must end with one of three statuses: Confirmed, Rejected, Uncertain. |
---

| **Use Case Name:** | Annotation Workflow |
|--------------------|---------------------|
| **ID:** | UC-006 |
| **Importance Level:** | Medium |
| **Primary Actor:** | Doctor |
| **Use Case Type:** | Supporting Process |
| **Stakeholders and Interests:** | **Doctor:** Needs to correct AI prediction by annotating lesion.<br> **System:** Must capture annotation for model retraining. |
| **Brief Description:** | If the doctor rejects an AI prediction, they annotate the lesion area (bounding box, polygon, or freehand) and provide correct diagnosis. |
| **Trigger:** | Doctor rejects AI prediction in UC-005. |
| **Relationships:** | Extends: Doctor Decision |
| **Normal Flow of Events (including subflows):** | 1. System displays annotation tools.<br> 2. Doctor selects tool and marks lesion.<br> 3. Doctor inputs correct disease label.<br> 4. System saves annotation and updates case. |
| **Alternate/Exceptional Flow:** | - If annotation is incomplete → system prompts to finish.<br> - If image corrupted → doctor uploads a new image. |
| **Note:** | Annotations may be used for AI model retraining. |
---

| **Use Case Name:** | Specialist Referral |
|--------------------|---------------------|
| **ID:** | UC-007 |
| **Importance Level:** | Medium |
| **Primary Actor:** | Doctor |
| **Use Case Type:** | Supporting Process |
| **Stakeholders and Interests:** | **Doctor:** Needs second opinion.<br> **Specialist:** Reviews uncertain cases.<br> **System:** Must route referral and notify specialist. |
| **Brief Description:** | If the doctor is uncertain, the case is referred to a specialist who reviews the images and data to provide feedback. |
| **Trigger:** | Doctor selects “Uncertain” in UC-005. |
| **Relationships:** | Extends: Doctor Decision |
| **Normal Flow of Events (including subflows):** | 1. Doctor marks case as Uncertain.<br> 2. System forwards case to specialist queue.<br> 3. Specialist reviews case and records decision.<br> 4. System updates case status and notifies doctor. |
| **Alternate/Exceptional Flow:** | - If no specialist available → case marked pending.<br> - If referral fails due to network error → system retries. |
| **Note:** | Specialist decision overrides AI suggestion. |
---

| **Use Case Name:** | Dashboard & Metrics |
|--------------------|---------------------|
| **ID:** | UC-008 |
| **Importance Level:** | Medium |
| **Primary Actor:** | Doctor |
| **Use Case Type:** | Information Process |
| **Stakeholders and Interests:** | **Doctor:** Needs overview of case workload and decisions.<br> **System:** Must present real-time statistics. |
| **Brief Description:** | Doctor views dashboard showing number of cases handled, distribution of Confirmed/Rejected/Uncertain, pending annotations, and model performance metrics. |
| **Trigger:** | Doctor logs in or navigates to dashboard. |
| **Relationships:** | None |
| **Normal Flow of Events (including subflows):** | 1. Doctor opens dashboard.<br> 2. System retrieves case statistics.<br> 3. System displays charts and pending tasks.<br> 4. Doctor may filter by time range or disease type. |
| **Alternate/Exceptional Flow:** | - If no data available → system shows “No cases found.”<br> - If server error → display fallback message. |
| **Note:** | Dashboard supports filtering and drill-down for detailed case view. |
---

| **Use Case Name:** | Case History |
|--------------------|--------------|
| **ID:** | UC-009 |
| **Importance Level:** | Low |
| **Primary Actor:** | Doctor |
| **Use Case Type:** | Information Process |
| **Stakeholders and Interests:** | **Doctor:** Needs access to past cases.<br> **System:** Must store and retrieve case history. |
| **Brief Description:** | Doctor searches and views past cases with their predictions, annotations, and outcomes. |
| **Trigger:** | Doctor opens case history page. |
| **Relationships:** | None |
| **Normal Flow of Events (including subflows):** | 1. Doctor opens case history.<br> 2. System lists previous cases.<br> 3. Doctor selects a case.<br> 4. System displays details, images, and decisions. |
| **Alternate/Exceptional Flow:** | - If no past cases exist → system shows blank state with “No cases found.” |
| **Note:** | Useful for follow-ups and research. |
---

| **Use Case Name:** | Logout |
|--------------------|--------|
| **ID:** | UC-010 |
| **Importance Level:** | Low |
| **Primary Actor:** | Doctor |
| **Use Case Type:** | Supporting Process |
| **Stakeholders and Interests:** | **Doctor:** Wants to exit securely.<br> **System:** Must clear session data. |
| **Brief Description:** | Doctor securely logs out of the system, ending active session. |
| **Trigger:** | Doctor clicks “Logout” button. |
| **Relationships:** | None |
| **Normal Flow of Events (including subflows):** | 1. Doctor clicks Logout.<br> 2. System ends session and clears tokens.<br> 3. Login page is displayed. |
| **Alternate/Exceptional Flow:** | - If session already expired → system redirects to login.<br> - If logout fails → force timeout. |
| **Note:** | Ensures data security and session integrity. |
---

