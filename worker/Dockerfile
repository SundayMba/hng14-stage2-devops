FROM python:3.11-slim AS builder

ENV VENV_PATH=/opt/venv \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build

RUN python -m venv "${VENV_PATH}"
COPY requirements.txt .
RUN "${VENV_PATH}/bin/pip" install -r requirements.txt

FROM python:3.11-slim AS runtime

ENV VENV_PATH=/opt/venv \
    PATH="/opt/venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN addgroup --system app && adduser --system --ingroup app app

COPY --from=builder "${VENV_PATH}" "${VENV_PATH}"
COPY --chown=app:app worker.py ./

USER app

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 CMD python -c "import os, sys, time; path = os.getenv('WORKER_HEARTBEAT_FILE', '/tmp/worker-heartbeat'); sys.exit(0 if os.path.exists(path) and time.time() - os.path.getmtime(path) < 20 else 1)"

CMD ["python", "worker.py"]
