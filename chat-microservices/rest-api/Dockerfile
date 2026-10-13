# --------------------------------------------------
# Stage 1 — Dependency builder
# --------------------------------------------------
FROM python:3.11-alpine@sha256:303398d5c9f110790bce60d64f902e51e1a061e33292985c72bf6cd07960bf09 AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

# Copy dependencies first to maximize Docker layer caching
COPY rest-api/requirements.txt .

# Install application dependencies
RUN python -m venv /opt/venv \
    #&& /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt \
    && rm -rf /opt/venv/lib/python3.11/site-packages/pip \
              /opt/venv/lib/python3.11/site-packages/pip-*.dist-info \
              /opt/venv/lib/python3.11/site-packages/setuptools \
              /opt/venv/lib/python3.11/site-packages/setuptools-*.dist-info \
              /opt/venv/lib/python3.11/site-packages/wheel \
              /opt/venv/lib/python3.11/site-packages/wheel-*.dist-info


# --------------------------------------------------
# Stage 2 — Production runtime
# --------------------------------------------------
FROM python:3.11-alpine@sha256:303398d5c9f110790bce60d64f902e51e1a061e33292985c72bf6cd07960bf09 AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Upgrade Alpine security packages and remove unused packaging tools
RUN apk upgrade --no-cache \
    && addgroup -S appgroup -g 1001 \
    && adduser -S appuser -u 1001 -G appgroup \
    && rm -rf /usr/local/lib/python3.11/site-packages/pip \
              /usr/local/lib/python3.11/site-packages/pip-*.dist-info \
              /usr/local/lib/python3.11/site-packages/setuptools \
              /usr/local/lib/python3.11/site-packages/setuptools-*.dist-info \
              /usr/local/lib/python3.11/site-packages/wheel \
              /usr/local/lib/python3.11/site-packages/wheel-*.dist-info

# Copy only application dependencies
COPY --from=builder /opt/venv /opt/venv

# Copy application source
COPY --chown=appuser:appgroup rest-api/src ./src

USER 1001

EXPOSE 3001

# Container healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:3001/api/health', timeout=3)"

# Production WSGI server
CMD ["gunicorn", \
     "--bind", "0.0.0.0:3001", \
     "--workers", "1", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "--log-level", "info", \
     "--capture-output", \
     "--graceful-timeout", "30", \
     "src.app:app"]