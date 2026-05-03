"""
Portfolio app — production Flask service.

Exposes:
  GET /           → simple response (workload)
  GET /health/live  → liveness probe (is process alive?)
  GET /health/ready → readiness probe (is app ready to serve traffic?)
  GET /metrics    → Prometheus scrape endpoint

Design decisions:
  - /health/live and /health/ready are SEPARATE endpoints.
    Liveness failure → K8s restarts the container.
    Readiness failure → K8s removes pod from Service endpoints (no restart).
    Splitting them prevents K8s from killing a pod that's alive but temporarily
    unable to serve (e.g. DB connection retry in progress).

  - prometheus_client multiprocess mode disabled here because this runs
    single-process under Gunicorn with threads. For multi-worker Gunicorn
    you would set PROMETHEUS_MULTIPROC_DIR and use make_wsgi_app().

  - Structured logging (key=value) makes log lines parseable by Loki
    without a custom pipeline — Loki can filter on key=value pairs directly.
"""

import logging
import os
import time

from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

# ---------------------------------------------------------------------------
# Logging — structured key=value so Loki can filter without a parsing pipeline
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="time=%(asctime)s level=%(levelname)s msg=%(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------
app = Flask(__name__)

# Pulled from env so the same image runs in every environment.
# K8s injects these via the Helm values → deployment.yaml envFrom.
APP_ENV = os.environ.get("APP_ENV", "development")
APP_VERSION = os.environ.get("APP_VERSION", "unknown")

# ---------------------------------------------------------------------------
# Prometheus metrics
#
# Counter:   monotonically increasing — use rate() at query time, never gauge math
# Histogram: samples observations into buckets — use histogram_quantile() for p99
#
# Label cardinality rule: keep label values bounded.
# method + endpoint + status is fine; never use user_id or request_id as labels
# (unbounded cardinality → Prometheus OOM).
# ---------------------------------------------------------------------------
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)

REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
    # Buckets tuned for a lightweight web service.
    # Adjust upper bound based on your p99 SLO target.
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5],
)

# ---------------------------------------------------------------------------
# Middleware — record metrics on every request automatically
# ---------------------------------------------------------------------------
@app.before_request
def start_timer():
    request._start_time = time.monotonic()


@app.after_request
def record_metrics(response):
    latency = time.monotonic() - request._start_time
    endpoint = request.path
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=endpoint,
        status=response.status_code,
    ).inc()
    REQUEST_LATENCY.labels(
        method=request.method,
        endpoint=endpoint,
    ).observe(latency)
    return response


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.route("/")
def index():
    logger.info("msg=index_request env=%s version=%s", APP_ENV, APP_VERSION)
    return jsonify(
        {
            "service": "core-api",
            "env": APP_ENV,
            "version": APP_VERSION,
            "status": "ok",
        }
    )


@app.route("/health/live")
def liveness():
    """
    Liveness probe — answers: is the process alive and not deadlocked?

    Returns 200 as long as the process is running and the event loop is
    responsive. Does NOT check dependencies (DB, cache) — that's readiness.

    If this probe fails, K8s restarts the container. Keep it lightweight.
    """
    return jsonify({"status": "alive"}), 200


@app.route("/health/ready")
def readiness():
    """
    Readiness probe — answers: is the app ready to serve user traffic?

    Here you would check:
      - DB connection pool has available connections
      - Required feature flags are loaded
      - Any warm-up tasks are complete

    If this probe fails, K8s removes the pod from the Service's endpoint list.
    No restart — just traffic isolation until the pod recovers.
    """
    # In a real service: check DB, cache, downstream dependencies here.
    # Return 503 + {"status": "not_ready", "reason": "..."} if any check fails.
    return jsonify({"status": "ready"}), 200


@app.route("/metrics")
def metrics():
    """
    Prometheus scrape endpoint.

    The ServiceMonitor in observability/ points Prometheus here.
    Do not put auth in front of this in a cluster — Prometheus scrapes
    from inside the cluster where NetworkPolicy already restricts access.
    """
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


# ---------------------------------------------------------------------------
# Entry point (used by local dev only — Gunicorn ignores this in production)
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)