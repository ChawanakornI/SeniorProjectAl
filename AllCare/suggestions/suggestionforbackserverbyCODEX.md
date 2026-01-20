## Backserver deployment suggestions (CODEX)

This repo contains a Flutter client and a FastAPI backend (`backserver/`) that loads a PyTorch ResNet50 skin‑lesion model from `assets/models/`. Below is a practical real‑world deployment approach for the backend when moving to cloud.

### 1) Target architecture

- Deploy Flutter separately (mobile stores + optional web CDN).
- Deploy `backserver` as an HTTPS JSON API.
- Treat the backend as stateless compute; move images/metadata to managed storage.

Typical flow:
1. Client uploads image → backend `/check-image`.
2. Backend runs preprocessing + inference.
3. Backend writes image + metadata to durable services.
4. Backend returns predictions + IDs/URLs.

### 2) Containerize the backend

Create a Docker image that bundles the code and (optionally) the model.

**Example Dockerfile**

```dockerfile
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY backserver/requirements.txt /app/backserver/requirements.txt
RUN pip install --no-cache-dir -r /app/backserver/requirements.txt

# Copy backend and models (bake models into image)
COPY backserver/ /app/backserver/
COPY assets/models/ /app/assets/models/

ENV MODEL_PATH=/app/assets/models/ham10000_resnet50_tuned_best.pt \
    BACKSERVER_HOST=0.0.0.0 \
    BACKSERVER_PORT=8000

EXPOSE 8000

CMD ["gunicorn", "-k", "uvicorn.workers.UvicornWorker", "backserver.back:app", "--bind", "0.0.0.0:8000", "--workers", "2", "--timeout", "120"]
```

Notes:
- Baking the model in is simplest for a single model updated infrequently.
- If the model is large or updated often, download it at startup from object storage instead.

### 3) Cloud runtime options

**CPU inference (simplest)**
- Google Cloud Run, AWS App Runner, AWS Fargate, Fly.io, Render, Railway.
- Pros: easy deploy, autoscaling, HTTPS built in.
- Cons: slower inference vs GPU.

**GPU inference**
- Kubernetes with GPU nodes (GKE/EKS/AKS), ECS with GPU, or managed ML endpoints (Vertex AI / SageMaker).
- Pros: faster inference, higher throughput.
- Cons: higher cost, more ops.

Rule of thumb:
- If latency is OK on CPU (e.g., <1–2s/image), start with CPU.
- Move to GPU when you need scale or sub‑second latency.

### 4) Persisting images and metadata

Current code writes to local disk (`backserver/storage`, `metadata.jsonl`). In cloud these disks are ephemeral.

Suggested replacements:
- **Images** → S3 / GCS / Azure Blob.
- **Metadata** → Postgres, Firestore, DynamoDB, or a log analytics sink.

Implementation idea:
- Replace `_save_image` to upload to object storage and return a URL.
- Replace `_append_metadata` to insert into a DB table or publish to a queue/log.

### 5) Environment configuration

Keep all deployment‑specific settings as env vars.

Important variables in `backserver/config.py`:
- `MODEL_PATH` (or `MODEL_URL` if you add downloads)
- `MODEL_DEVICE=cpu|cuda|mps`
- `BLUR_THRESHOLD`, `CONF_THRESHOLD`
- `ALLOWED_ORIGINS`
- `API_KEY`

Store secrets in a secret manager (Cloud Run Secrets, AWS Secrets Manager, etc.), not in git.

### 6) Security & reliability hardening

- Restrict CORS to real client origins.
- Enforce max upload size (FastAPI/ASGI middleware) and validate content type.
- Add rate limiting (e.g., `slowapi`, Cloud Armor/WAF).
- Add structured logging and tracing (Cloud Logging/CloudWatch).
- Health checks already exist at `/health`.

### 7) CI/CD outline

GitHub Actions pipeline:
1. Lint/test backend.
2. Build/push Docker image to registry.
3. Deploy to your service on `main`.

Also consider a staging environment with its own model/version.

### 8) Concrete starter path

1. Add Dockerfile and build locally:
   - `docker build -t always-backserver .`
   - `docker run -p 8000:8000 always-backserver`
2. Choose a CPU platform (e.g., Cloud Run).
3. Push image and deploy with env vars + secrets set.
4. Migrate storage to object store + DB once traffic grows.

