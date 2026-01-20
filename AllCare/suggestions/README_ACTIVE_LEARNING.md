# Active Learning (Margin Sampling) Implementation Plan

This document outlines how to integrate active learning (AL) using margin
sampling over rejected cases to improve model performance via selective
labeling. The plan keeps the existing FastAPI routes stable and adds a small
set of AL-focused APIs, data fields, and offline retraining steps.

## Goals

- Use rejected cases as the AL pool.
- Prioritize labeling of the most ambiguous predictions (smallest margin).
- Persist labels and training metadata to track improvements over time.
- Keep the current app and backend flows working without breaking changes.

## Scope

In:
- Margin computation and storage on rejected cases.
- Candidate selection endpoint for labeling.
- Label submission endpoint and audit fields.
- Dataset export for retraining and a reproducible training workflow.
- Optional doctor-only UI flow for labeling.

Out:
- Fully automated retraining and deployment.
- MLOps infrastructure (model registry, CI/CD for models).
- Changes to mobile/Flutter flows unrelated to labeling.

## Current Context (Backend)

- Rejected cases are logged via `POST /cases/reject` in `backserver/back.py`.
- Case metadata lives in `backserver/storage/metadata.jsonl`.
- `backserver/model.py` returns a list of class probabilities (sorted).

## Design Overview

1) When a case is rejected, compute a margin:
   margin = top1_confidence - top2_confidence
   Smaller margin = more ambiguous prediction.

2) Store margin and label status in the case metadata.

3) Provide an endpoint to fetch candidate cases for labeling, sorted by
   smallest margin and filtered to only rejected, unlabeled entries.

4) Provide an endpoint to submit labels and mark the case as labeled.

5) Export labeled rejected cases for offline retraining; update the model
   and track model version in future inferences.

## Data Model Changes

Add these fields to rejected case entries (JSONL or DB):

- margin: float (top1 - top2)
- label_status: "unlabeled" | "labeled"
- true_label: string (ground-truth class)
- labeled_by: string (user id or role)
- labeled_at: ISO timestamp
- model_version: string (identifier for the model used at inference time)

Optional:
- label_notes: string
- label_source: "doctor" | "offline" | "import"

## API Additions

1) GET /active-learning/candidates
   Query parameters:
   - limit (default 50)
   - max_margin (optional filter)
   - include_without_predictions (default false)
   Returns:
   - list of rejected cases with smallest margin, unlabeled only.

2) POST /active-learning/label
   Request body:
   - case_id
   - image_id (optional)
   - true_label
   - labeled_by
   - labeled_at (optional)
   - label_notes (optional)
   Response:
   - status and updated case entry fields.

Optional:
3) GET /active-learning/stats
   Counts of rejected, labeled, and pending labels.

## Backend Implementation Steps

1) Extend schemas:
   - Add label metadata fields to `RejectCase` (and/or new models).
   - Add new request/response models for AL endpoints.

2) Compute margin on reject:
   - Use the predictions list in the reject payload.
   - If fewer than 2 predictions exist, set margin to null and exclude from
     candidate selection by default.

3) Persist AL fields:
   - Write margin, label_status, model_version into `metadata.jsonl`.
   - Default label_status = "unlabeled".

4) Candidate selection:
   - Filter entries: entry_type == "reject" and label_status == "unlabeled".
   - Require margin not null and (optional) margin <= max_margin.
   - Sort ascending by margin, then by created_at desc.
   - Apply limit.

5) Label submission:
   - Update the matching entry with true_label and audit fields.
   - If JSONL is used, rewrite the file or append a label update record
     and resolve latest state on read (choose one approach).

6) Add config knobs in `backserver/config.py`:
   - AL_MAX_CANDIDATES
   - AL_MAX_MARGIN (optional)
   - MODEL_VERSION

## Optional UI Integration (Doctor Only)

- Add a "Label Rejected Cases" entry point from Notifications or Case Detail.
- Show candidate queue sorted by smallest margin.
- Allow doctor to select true label and submit.
- Show label status and labeling history on case details.

## Retraining Workflow (Offline)

1) Export labeled rejected cases:
   - Include image paths, true labels, and any metadata needed for training.
   - Generate a CSV or JSON manifest for the training script.

2) Retrain model:
   - Start with the current model as a baseline.
   - Combine labeled rejected cases with existing training data.
   - Track metrics and compare to baseline.

3) Publish model:
   - Save new model artifact and update `MODEL_PATH`.
   - Bump `MODEL_VERSION` in config.

## Testing and Validation

- Unit test margin computation with 0, 1, and 2+ predictions.
- API tests for candidate selection ordering and filters.
- API test for label submission and persistence.
- Manual verification that `/cases` returns entries unchanged for existing
  clients.

## Risks and Edge Cases

- Rejected cases may be biased toward confusing or low-quality images.
- Sparse labels may not be enough to improve the model.
- Duplicate labeling or conflicting labels requires a policy (overwrite vs
  audit history).
- JSONL updates can be tricky; consider a DB migration if labeling volume
  grows.

## Open Questions

- Who provides labels (doctor only, offline dataset, or admin tool)?
- Is true_label single-class only, or can it be multi-label/unknown?
- Should labeled rejected cases be excluded from future candidate lists?

