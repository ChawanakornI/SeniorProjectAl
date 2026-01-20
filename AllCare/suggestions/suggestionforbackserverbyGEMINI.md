## Backserver deployment suggestions (GEMINI)

This document proposes a real‑world deployment plan for the FastAPI + PyTorch backend in `backserver/`, assuming the Flutter client is distributed separately.

### A. High‑level goal

Deliver a reliable, secure inference API that can scale on demand, while keeping the client lightweight.

### B. Suggested production architecture

- **Client**: Flutter (Android/iOS) and optional Flutter Web on a CDN.
- **API**: FastAPI backend behind HTTPS.
- **Model**: PyTorch `.pt` file versioned and managed outside the code.
- **Storage**:
  - Images → object storage (S3/GCS/Blob).
  - Case logs / metadata → managed database or log sink.

### C. Model deployment strategy

Pick one based on update frequency:

1) **Model baked into container**
- Copy `assets/models/` into the Docker image.
- Backend uses the default relative `MODEL_PATH`.
- Best for small models and rare updates.

2) **Model pulled from cloud on startup**
- Upload model to object storage and set `MODEL_URL`/`MODEL_PATH`.
- Download to a local cache folder during service start.
- Best for frequent updates and clean rollbacks.

Add explicit versioning like `ham10000_resnet50_v3.pt` so you can roll forward by flipping an env var.

### D. Cloud hosting options

**Start here (CPU)**
- Cloud Run / App Runner / Fargate / Fly.io / Render / Railway.
- Autoscale to zero, minimal ops, good for MVP.

**Upgrade to GPU when needed**
- GPU‑enabled Kubernetes or ECS, or managed ML endpoints.
- Use GPU once latency/throughput targets are not met on CPU.

### E. Production concerns to address

- **Ephemeral disk**: do not rely on `backserver/storage` or `metadata.jsonl` in production.
- **Security**:
  - Replace a single global `API_KEY` with user auth if public.
  - Restrict `ALLOWED_ORIGINS` to your real app domains.
  - Add rate limits and max upload size.
- **Observability**:
  - Centralized logs, latency metrics, error tracking.
  - Alert on high error rate or inference slowdown.

### F. CI/CD recommendation

Automate:
1. Run tests/lint.
2. Build Docker image.
3. Push to registry.
4. Deploy to staging → then production.

Maintain separate env vars per environment (dev/staging/prod), especially for model version and storage buckets.

### G. Minimal rollout plan

1. Dockerize backend and verify locally.
2. Deploy to a CPU managed container service.
3. Configure env vars + secrets in the cloud console.
4. Switch storage to object store + DB before scaling.
5. Measure latency; move to GPU if required.

