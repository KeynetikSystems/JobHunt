# Builds the backend (backend/app.py) for deployment. Lives at the repo root
# rather than inside backend/ because the backend imports digest_engine.py,
# config.py, and send_report.py from here — a "shared monorepo" in Railway's
# terms, so the build needs the full repo, not just the backend/ subfolder.
FROM python:3.11-slim

WORKDIR /app

# Installed before the rest of backend/ is copied in, so this layer stays
# cached across rebuilds that only change application code.
COPY backend/requirements.txt backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

COPY digest_engine.py config.py send_report.py PRIVACY.md TERMS.md ./
COPY backend/ backend/

WORKDIR /app/backend
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]
