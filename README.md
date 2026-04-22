# Job Processing Stack

This repository contains a four-part job processing system:

- `frontend`: Express UI for submitting and tracking jobs
- `api`: FastAPI service for job creation and status lookups
- `worker`: Python worker that consumes queued jobs
- `redis`: shared queue and state store

## Prerequisites

- Git
- Docker Engine or Docker Desktop
- Docker Compose v2

Optional for manual non-Docker runs:

- Python 3.11 or newer
- Node.js 18 or newer
- npm

## Environment Setup

Copy the example configuration:

```bash
cp .env.example .env
```

The Compose stack reads its runtime configuration from `.env`.

## Bring The Full Stack Up

1. Clone your fork and enter the project:

```bash
git clone <your-fork-url>
cd hng14-stage2-devops
```

2. Create the local env file:

```bash
cp .env.example .env
```

3. Build and start all services:

```bash
docker compose up -d --build
```

4. Check the service state:

```bash
docker compose ps
```

5. Open the frontend:

```text
http://127.0.0.1:3000
```

## What Successful Startup Looks Like

- `docker compose ps` shows `redis` as `healthy`
- `docker compose ps` shows `api` as `healthy`
- `docker compose ps` shows `worker` as `healthy`
- `docker compose ps` shows `frontend` as `healthy`
- `redis` is not exposed on the host
- `frontend` is reachable on `http://127.0.0.1:3000`
- `api` is reachable on `http://127.0.0.1:8000/health`
- submitting a job from the frontend eventually changes its status to `completed`

## Quick Verification Commands

Verify the API health endpoint:

```bash
curl http://127.0.0.1:8000/health
```

Submit a job through the frontend wrapper:

```bash
curl -X POST http://127.0.0.1:3000/submit
```

Check worker activity:

```bash
docker compose logs worker
```

## Stop The Stack

```bash
docker compose down -v
```

## Network Layout

- `app-internal`: named internal Docker network shared by all services for service-to-service traffic
- `edge`: host-facing network used by `frontend` and `api` for published ports

This keeps Redis off the host while still allowing local browser access to the frontend and API.

## Manual Fallback Run

If you want to run each service individually outside Docker:

1. Start Redis:

```bash
redis-server
```

2. Start the API:

```bash
cd api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export REDIS_HOST=localhost
export REDIS_PORT=6379
export REDIS_DB=0
export JOB_QUEUE_NAME=job
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

3. Start the worker:

```bash
cd worker
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export REDIS_HOST=localhost
export REDIS_PORT=6379
export REDIS_DB=0
export JOB_QUEUE_NAME=job
python worker.py
```

4. Start the frontend:

```bash
cd frontend
npm install
API_URL=http://localhost:8000 PORT=3000 npm start
```
