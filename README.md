# Job Processing Stack

This repository contains four components:

- `frontend`: Node.js UI for submitting and checking jobs
- `api`: FastAPI service that creates jobs and returns job status
- `worker`: Python worker that processes queued jobs
- `redis`: shared queue and state store

## Prerequisites

- Git
- Python 3.11 or newer
- Node.js 18 or newer
- npm
- Redis 7 or newer

## Environment Variables

The API currently reads its Redis settings from environment variables.

Create a local env file from the example if you want a reference:

```bash
cp .env.example .env
```

The current API does not automatically load `.env`, so export the values in your shell before starting it.

## Start From Scratch

1. Clone the repository and enter it:

```bash
git clone <your-fork-url>
cd hng14-stage2-devops
```

2. Start Redis on port `6379`.

If Redis is installed locally:

```bash
redis-server
```

If you prefer Docker just for Redis:

```bash
docker run --rm -p 6379:6379 redis:7-alpine
```

3. Start the API in a new terminal:

```bash
cd api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export REDIS_HOST=localhost
export REDIS_PORT=6379
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

4. Start the worker in a second terminal:

```bash
cd worker
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python worker.py
```

5. Start the frontend in a third terminal:

```bash
cd frontend
npm install
npm start
```

## What Success Looks Like

- The API starts on `http://127.0.0.1:8000`
- The frontend starts on `http://127.0.0.1:3000`
- The worker prints `Processing job ...` and `Done: ...` after a job is submitted
- Opening `http://127.0.0.1:3000` shows the dashboard
- Clicking `Submit New Job` creates a job and eventually shows `completed`

## Quick Manual Checks

Create a job directly through the API:

```bash
curl -X POST http://127.0.0.1:8000/jobs
```

Check a job by ID:

```bash
curl http://127.0.0.1:8000/jobs/<job-id>
```

## Current Scope

This documentation reflects the repository in its current manual-run state. Containerization, CI/CD, and remaining service fixes can be added after the application behavior is corrected service by service.
