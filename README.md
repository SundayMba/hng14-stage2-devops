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

## Local Quality Checks

Install the shared development dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r api/requirements.txt -r worker/requirements.txt -r requirements-dev.txt
cd frontend && npm ci && cd ..
```

Run the same checks used by CI:

```bash
.venv/bin/flake8 api worker tests
.venv/bin/pytest --cov=api --cov-report=term-missing --cov-report=xml tests/api
cd frontend && npm run lint && cd ..
./scripts/integration-test.sh .env
```

## CI/CD Pipeline

GitHub Actions runs the pipeline in this exact order:

1. `lint`
2. `test`
3. `build`
4. `security scan`
5. `integration test`
6. `deploy`

Pipeline details:

- `lint` runs `flake8`, `eslint`, and `hadolint`
- `test` runs mocked-Redis API unit tests with coverage artifact upload
- `build` builds all three images, tags them with `${GITHUB_SHA}` and `latest`, and pushes them to a local `registry:2` service container
- `security scan` runs Trivy against all images, fails on any `CRITICAL` finding, and uploads SARIF results as artifacts
- `integration test` boots the full stack in the runner and asserts a submitted job completes successfully
- `deploy` runs only on pushes to `main` and uses `scripts/deploy.sh` for a health-gated rolling update with rollback to the previous container if the replacement fails within 60 seconds

## GitHub Deploy Secrets

Set these repository secrets before enabling deploys from `main`:

- `DEPLOY_HOST`: public IP or hostname of the target server
- `DEPLOY_USER`: SSH user on the target server
- `DEPLOY_SSH_KEY`: private SSH key for that user

Optional repository variable:

- `DEPLOY_PATH`: remote directory used to copy the deploy payload. Defaults to `jobprocessor-deploy`.

Deploy target requirements:

- Docker must already be installed on the target host
- the SSH user must be able to run Docker commands
- the deploy verification runs over SSH on the target host, so `3000` does not need to be publicly exposed
- if you use Nginx or another reverse proxy, point it at `http://127.0.0.1:${FRONTEND_HOST_PORT}`

## Nginx Reverse Proxy

The default `.env.example` binds the frontend and API host ports to `127.0.0.1`, which fits a reverse-proxy deployment on EC2.

Example Nginx upstream for the frontend:

```nginx
location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
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
