FROM python:3.11-slim AS builder

ENV VENV_PATH=/opt/venv \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build

RUN python -m venv "${VENV_PATH}"
COPY requirements-prod.txt .
RUN "${VENV_PATH}/bin/pip" install -r requirements-prod.txt

FROM python:3.11-slim AS runtime

ENV VENV_PATH=/opt/venv \
    PATH="/opt/venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN addgroup --system app && adduser --system --ingroup app app

COPY --from=builder "${VENV_PATH}" "${VENV_PATH}"
COPY --chown=app:app main.py ./

USER app
EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 CMD python -c "import os, sys, urllib.request; port = os.getenv('API_PORT', '8000'); sys.exit(0 if urllib.request.urlopen(f'http://127.0.0.1:{port}/health').getcode() == 200 else 1)"

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${API_PORT:-8000}"]
