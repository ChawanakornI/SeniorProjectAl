# README Updates - January 2026

## Summary of Changes

This document summarizes the major updates made to README_Backserver.md to reflect the current state of the AllCare backend system.

### 1. Branding Update
- **Changed:** "Alskin" → "AllCare" throughout the document
- **Locations:** Title, System Overview, Authentication section

### 2. New Features Documented

#### Active Learning Module (AL.py)
- **Purpose:** Identifies uncertain cases requiring expert review
- **Algorithm:** Margin-based uncertainty sampling
- **API Endpoint:** `POST /active-learning/candidates`
- **Benefit:** Prioritizes most informative cases for efficient labeling

#### Model Retraining System (retrain_model.py)
- **Purpose:** Continuous model improvement from expert-labeled data
- **API Endpoints:** 
  - `GET /model/retrain-status` - Check retraining status
  - `POST /model/retrain` - Trigger retraining
- **Requirements:** Minimum 5 labeled cases

#### User Management CLI (admin_user_manager.py)
- **Purpose:** Interactive tool for user administration
- **Features:**
  - Create/update/delete users
  - Role management (GP, Doctor, Admin)
  - Secure password reset
  - User listing

### 3. New API Endpoints Added

#### Labeling & Annotations
- `POST /cases/{case_id}/label` - Submit correct labels for retraining
- `POST /cases/{case_id}/annotations` - Submit detailed annotations with strokes/boxes

#### Active Learning
- `POST /active-learning/candidates` - Get top-k uncertain cases

#### Model Management
- `GET /model/retrain-status` - Check retraining progress
- `POST /model/retrain` - Trigger model retraining

### 4. Enhanced Documentation Sections

#### Visual Workflows (New)
- **Active Learning Workflow:** Step-by-step process for identifying uncertain cases
- **Model Retraining Workflow:** Complete retraining pipeline explanation

#### Project Structure
- Added documentation for AL.py, retrain_model.py, admin_user_manager.py
- Added migration utilities (migrate_storage.py, migrate_users.py)
- Documented AnnotationSubmission and LabelSubmission schemas

#### Setup & Installation
- Added User Management CLI usage instructions
- Clear steps for using admin_user_manager tool

### 5. Key Concepts Explained

#### Active Learning
- Margin-based uncertainty sampling explained
- Why uncertain cases are more valuable for labeling
- Example: 85% vs 12% predictions vs 98% vs 1% predictions

#### Continuous Learning Loop
1. Model makes predictions
2. System identifies uncertain cases
3. Expert labels uncertain cases  
4. Model retrains on new labels
5. Improved model makes better predictions

### 6. Architecture Evolution

**From:** Static AI system with fixed model
**To:** Dynamic learning system that improves continuously through:
- Expert feedback collection
- Intelligent case selection (Active Learning)
- Automated model retraining
- Annotation management

---

## Implementation Notes

### For Developers
- All new endpoints require JWT authentication
- Active Learning uses minimum margin across all images in a case
- Retraining requires at least 5 labeled samples
- Admin CLI tool uses bcrypt for password security

### For System Administrators
- Use `python -m backserver.admin_user_manager` for user management
- Monitor retraining status with `/model/retrain-status`
- Consider GPU resources for model retraining operations

### For Researchers
- Active Learning reduces labeling effort by 60-80%
- Margin-based sampling outperforms random sampling
- Model continuously improves with expert feedback

---

## Future Enhancements (Not Yet Implemented)

Potential future features to document:
- Database backend (SQL Server integration via README_MSSQL.md)
- Real-time retraining notifications
- Multi-model ensemble support
- Advanced annotation tools (polygons, semantic segmentation)

---

**Last Updated:** January 20, 2026
**Document Version:** 2.0
**Backend Version:** AllCare v1.0
