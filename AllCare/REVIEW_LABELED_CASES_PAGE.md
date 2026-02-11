# Review Labeled Cases Page - Specification

## Overview
A page for Specialists to review all labeled cases in the system, view annotation details, compare with AI predictions, and edit labels if needed. This serves as a quality control and audit feature for the labeled training data.

---

## Access Control
- **GPs**: ❌ Cannot access this page
- **Specialists**: ✅ Can view ALL labeled cases (regardless of which specialist labeled them)
- **Admins**: ✅ Can view ALL labeled cases (full access)

---

## Core Features

### 1. **Main Case List View**
Displays all labeled cases in the main page area with the following information for each case:

#### Case Card Information:
- **Case ID**: Unique identifier
- **Images**: Display all images from the case with annotation overlays
  - Strokes (freehand drawings)
  - Boxes (rectangular annotations)
  - Same visual style as the labeling page (AnnotateScreen)
- **User's Classification**: The diagnosis/label chosen by the user
- **Labeling Timestamp**: When the case was labeled
- **Labeled By**: Username/ID of the person who labeled it
- **AI Predictions Comparison**: Side-by-side view showing:
  - Original AI top predictions (with confidence scores)
  - User's chosen label
  - Visual indicator if user agreed/disagreed with AI

#### Interaction:
- **Edit Button**: Opens the case in annotation mode for re-labeling
- **History Button** (Optional): Opens drawer/modal showing edit history for this specific case

---

### 2. **Edit Functionality**
Users can re-label any case:

**Workflow:**
1. Click "Edit" button on a case card
2. Opens the AnnotateScreen (same as labeling page) with:
   - All images from the case
   - Previous annotations pre-loaded
   - Previous classification pre-selected
3. User can:
   - Modify annotations (strokes/boxes)
   - Change classification
   - Submit updated label
4. System saves new label with timestamp
5. Returns to review page with updated information

**Data Tracking:**
- Store edit history (optional feature)
- Track who made the edit and when
- Preserve original label for audit purposes

---

### 3. **Edit History Drawer** (Optional Feature)
For each case, users can view the complete labeling history:

**History Information:**
- **Original Label**:
  - Date/time
  - User who labeled
  - Classification chosen
- **Edit Records** (if any):
  - Date/time of edit
  - User who edited
  - Previous classification → New classification
  - Reason for change (optional field)

**UI Pattern:**
- Mini drawer/modal that slides in from right or bottom
- Timeline view showing chronological history
- Can be triggered by clicking a "History" icon/button on each case card

---

## UI/UX Design Recommendations

### Layout Structure
```
┌─────────────────────────────────────────────────┐
│  App Bar: "Review Labeled Cases"               │
│  [Refresh Button]                               │
└─────────────────────────────────────────────────┘
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │ Case Card                                 │ │
│  │ ┌─────────────────────────────────────┐   │ │
│  │ │ Case #12345                         │   │ │
│  │ │ Labeled by: Dr. Smith               │   │ │
│  │ │ Date: 2026-01-20 14:30              │   │ │
│  │ └─────────────────────────────────────┘   │ │
│  │                                           │ │
│  │ Images with Annotations:                  │ │
│  │ ┌─────┐ ┌─────┐ ┌─────┐                  │ │
│  │ │ IMG1│ │ IMG2│ │ IMG3│                  │ │
│  │ │  🖍️ │ │  🖍️ │ │  🖍️ │                  │ │
│  │ └─────┘ └─────┘ └─────┘                  │ │
│  │                                           │ │
│  │ AI Predictions vs User Label:             │ │
│  │ ┌──────────────────┬──────────────────┐  │ │
│  │ │ AI Predicted:    │ User Labeled:    │  │ │
│  │ │ Melanoma (85%)   │ ✓ Melanoma       │  │ │
│  │ │ Nevus (12%)      │                  │  │ │
│  │ └──────────────────┴──────────────────┘  │ │
│  │ ✓ Agreement                              │ │
│  │                                           │ │
│  │ [Edit Label] [History 📜]                 │ │
│  └───────────────────────────────────────────┘ │
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │ Case Card #2...                           │ │
│  └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### Visual Indicators
- ✅ **Green border/badge**: User label matches AI top prediction
- ⚠️ **Orange border/badge**: User label differs from AI prediction
- 🖍️ **Annotation overlay**: Show strokes/boxes on images with semi-transparent overlay
- 📜 **History icon**: Small icon button to open edit history drawer

---

## Data Requirements

### API Endpoints Needed

#### 1. Get All Labeled Cases
```
GET /api/cases/labeled
Headers: user_id, user_role
Query params:
  - page (optional)
  - limit (optional)
Response:
{
  "cases": [
    {
      "case_id": "12345",
      "images": [
        {
          "path": "uploads/...",
          "annotations": {
            "strokes": [...],
            "boxes": [...]
          }
        }
      ],
      "user_label": {
        "classification": "Melanoma",
        "labeled_by": "user123",
        "labeled_by_name": "Dr. Smith",
        "timestamp": "2026-01-20T14:30:00Z",
        "image_index": 0
      },
      "ai_predictions": [
        {"label": "Melanoma", "confidence": 0.85},
        {"label": "Nevus", "confidence": 0.12}
      ],
      "agreement": true
    }
  ],
  "total": 150,
  "page": 1,
  "pages": 15
}
```

#### 2. Get Case Label History (Optional)
```
GET /api/cases/{case_id}/label-history
Headers: user_id, user_role
Response:
{
  "case_id": "12345",
  "history": [
    {
      "version": 1,
      "classification": "Melanoma",
      "labeled_by": "user123",
      "labeled_by_name": "Dr. Smith",
      "timestamp": "2026-01-20T14:30:00Z",
      "is_original": true
    },
    {
      "version": 2,
      "classification": "Nevus",
      "labeled_by": "user456",
      "labeled_by_name": "Dr. Jones",
      "timestamp": "2026-01-21T10:15:00Z",
      "is_original": false,
      "previous_classification": "Melanoma"
    }
  ]
}
```

#### 3. Update Label (Reuse Existing)
```
POST /api/cases/{case_id}/annotations
Headers: user_id, user_role
Body: {
  "image_index": 0,
  "correct_label": "Nevus",
  "strokes": [...],
  "boxes": [...]
}
```

### Database Schema Considerations

If implementing edit history, consider:
```sql
-- Label History Table
CREATE TABLE label_history (
  id SERIAL PRIMARY KEY,
  case_id VARCHAR NOT NULL,
  version INT NOT NULL,
  classification VARCHAR NOT NULL,
  labeled_by VARCHAR NOT NULL,
  timestamp TIMESTAMP DEFAULT NOW(),
  is_original BOOLEAN DEFAULT FALSE,
  annotations JSONB,
  FOREIGN KEY (case_id) REFERENCES cases(case_id)
);
```

---

## Implementation Checklist

### Phase 1: Core Functionality
- [ ] Create new route: `/review-labeled-cases`
- [ ] Create `ReviewLabeledCasesPage` widget
- [ ] Add route to navigation (Specialist/Admin only)
- [ ] Implement access control (block GP role)
- [ ] Backend: Create `/api/cases/labeled` endpoint
- [ ] Fetch and display labeled cases in card format
- [ ] Display images with annotation overlays
- [ ] Show user label vs AI predictions comparison
- [ ] Implement "Edit Label" button → opens AnnotateScreen
- [ ] Handle label update and refresh list

### Phase 2: Visual Enhancements
- [ ] Add agreement/disagreement visual indicators
- [ ] Style annotation overlays to match labeling page
- [ ] Add loading states and error handling
- [ ] Add empty state (no labeled cases)
- [ ] Implement refresh functionality

### Phase 3: History Feature (Optional)
- [ ] Backend: Create `/api/cases/{case_id}/label-history` endpoint
- [ ] Backend: Modify save annotations to track history
- [ ] Create history drawer/modal component
- [ ] Display label change timeline
- [ ] Add "History" button to case cards

---

## User Stories

### As a Specialist:
1. ✅ I want to see all labeled cases in one place so I can review the quality of our training data
2. ✅ I want to see the annotations (drawings) on images so I understand what areas were marked
3. ✅ I want to compare user labels with AI predictions so I can identify disagreements
4. ✅ I want to edit incorrect labels so we maintain high-quality training data
5. ✅ I want to see who labeled each case and when for accountability

### As an Admin:
1. ✅ I want all the specialist features plus the ability to review all users' work
2. ✅ (Optional) I want to see the history of label changes for audit purposes

---

## Future Enhancements (Not in Initial Scope)

These features are not currently required but could be valuable in future iterations:

1. **Filtering & Search**
   - Filter by date range
   - Filter by classification/diagnosis
   - Filter by labeling user
   - Filter by AI agreement/disagreement
   - Search by case ID

2. **Sorting**
   - Sort by date (newest/oldest)
   - Sort by classification
   - Sort by user

3. **Bulk Operations**
   - Bulk export to CSV
   - Bulk re-label

4. **Statistics Dashboard**
   - Total labeled cases count
   - Breakdown by classification
   - Agreement rate with AI
   - Labels per user

5. **Comments/Notes**
   - Allow users to add notes to cases
   - Tag cases for review

---

## Technical Notes

### File Structure
```
lib/
  pages/
    review_labeled_cases_page.dart     # Main page
    components/
      labeled_case_card.dart           # Case card widget
      label_history_drawer.dart        # History drawer (optional)
  features/
    case/
      labeled_cases_service.dart       # API service for labeled cases
```

### Reusable Components
- **AnnotateScreen**: Already exists, reuse for editing
- **Image rendering with annotations**: Extract logic from AnnotateScreen for display-only view
- **Glass morphism cards**: Reuse from existing theme

### Performance Considerations
- Implement pagination (load 10-20 cases at a time)
- Lazy load images
- Cache annotation data
- Consider virtual scrolling for large lists

---

## Related Files
- `lib/pages/overviewlabel.dart` - Active learning labeling page
- `lib/features/case/annotate_screen.dart` - Annotation UI (reuse for editing)
- `lib/features/case/case_service.dart` - Case API service (extend for labeled cases)

---

## Questions for Future Clarification
1. Should we show only "fully labeled" cases or also "partially labeled" ones?
2. Should Specialists be able to delete labels?
3. Should there be a "flag for review" feature?
4. Do we need role-based editing restrictions (e.g., only edit your own labels)?
5. Should we track why a label was changed (add a reason field)?

---

## Summary
This page provides a comprehensive review and quality control mechanism for labeled training data. It allows Specialists to audit, verify, and correct labels while maintaining transparency through optional edit history tracking. The design balances functionality with simplicity, focusing on the core needs while allowing for future enhancements.
