# =============================================================================
# Stage 1 — builder
#
# Uses the full python image so pip can compile any C-extension dependencies.
# Nothing from this stage reaches the final image except the installed packages.
# =============================================================================
FROM python:3.12-slim AS builder

WORKDIR /build

# Copy requirements first — Docker cache reuses this layer on every rebuild
# unless requirements.txt changes. Copying app/ before this would bust the
# pip install cache on every code change (expensive).
COPY app/requirements.txt .

# --no-cache-dir: don't write the pip HTTP cache to disk (smaller layer)
# --user:         install into /root/.local so we can COPY the dir into runtime
# --upgrade pip:  avoid "pip is not up to date" noise in CI logs
RUN pip install --upgrade pip --no-cache-dir \
 && pip install --no-cache-dir --user -r requirements.txt


# =============================================================================
# Stage 2 — runtime
#
# Starts from the same slim base — no compilers, no build tools, no pip.
# Only the app code and the pre-built packages from stage 1 come across.
#
# Why slim and not distroless? slim gives us /bin/sh for kubectl exec debugging
# in non-prod environments. Switch to distroless/python3-nonroot for prod-hardened
# images once the debug workflow is established.
# =============================================================================
FROM python:3.12-slim AS runtime

# Non-root user — defense-in-depth against container escape.
# If an attacker gets RCE inside the container, they are nobody, not root.
# UID 1001 avoids collision with common system UIDs (1000 = first human user).
RUN groupadd --gid 1001 appgroup \
 && useradd  --uid 1001 --gid appgroup --no-create-home appuser

WORKDIR /app

# Copy installed packages from builder — not pip itself, not gcc
COPY --from=builder /root/.local /home/appuser/.local

# Copy application source
COPY app/ .

# Ensure the package bin directory is on PATH so gunicorn is found
ENV PATH="/home/appuser/.local/bin:$PATH" \
    PYTHONPATH="/app" \
    # Don't buffer stdout — logs appear immediately in kubectl logs
    PYTHONUNBUFFERED=1 \
    # Don't write .pyc files — reduces image layer churn
    PYTHONDONTWRITEBYTECODE=1

USER appuser

EXPOSE 5000

# Gunicorn in production — NOT flask run.
# --workers: 2×CPU+1 is the standard formula; hardcoded to 2 for the portfolio
#            because EKS node groups are 2-core. Tune via APP_WORKERS env var.
# --threads: allows concurrent requests within a worker (I/O-bound workloads)
# --bind:    all interfaces inside the container; external access is via Service
# --timeout: 30s — kills stuck workers before K8s liveness probe fires (60s)
# --access-logfile -: write access logs to stdout so kubectl logs / Loki sees them
CMD ["gunicorn", \
     "--workers", "2", \
     "--threads", "2", \
     "--bind", "0.0.0.0:5000", \
     "--timeout", "30", \
     "--access-logfile", "-", \
     "main:app"]
