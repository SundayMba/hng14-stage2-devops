# Fix Log

Each entry lists the file, line numbers, the problem, and the change made.

- `api/.env:1-2`
  Problem: A tracked `.env` file contained secret-looking configuration and violated the requirement to keep `.env` files out of the repository.
  Fix: Removed `api/.env` from the working tree and replaced runtime configuration with environment variables plus `.env.example`.

- `api/main.py:9-19`
  Problem: The API hardcoded Redis to `localhost:6379` and did not expose the Redis DB or queue name as configuration.
  Fix: Added `REDIS_HOST`, `REDIS_PORT`, `REDIS_DB`, and `JOB_QUEUE_NAME` environment variables and enabled `decode_responses=True`.

- `api/main.py:22-31`
  Problem: The API had no health endpoint, so Docker and Compose could not verify readiness.
  Fix: Added `/health`, which pings Redis and returns `503` when Redis is unavailable.

- `api/main.py:34-40`
  Problem: `POST /jobs` pushed the job onto the queue before writing the initial status, creating a race with the worker.
  Fix: Wrote the initial `queued` status first and then pushed the job ID into the queue.

- `api/main.py:34-40`
  Problem: `POST /jobs` returned only `job_id` and used the default `200 OK` status for a create operation.
  Fix: Changed the endpoint to return `201 Created` and include both `job_id` and `status`.

- `api/main.py:43-51`
  Problem: `GET /jobs/{job_id}` returned a not-found payload with `200 OK`.
  Fix: Replaced the plain return with `HTTPException(status_code=404, detail="not found")`.

- `api/requirements.txt:1-3`
  Problem: API runtime dependencies were unpinned, which makes Docker builds less reproducible.
  Fix: Pinned `fastapi`, `uvicorn`, and `redis`.

- `worker/worker.py:8-24`
  Problem: The worker hardcoded Redis configuration and did not expose queue name, Redis DB, processing delay, or heartbeat file location as runtime settings.
  Fix: Added `REDIS_HOST`, `REDIS_PORT`, `REDIS_DB`, `JOB_QUEUE_NAME`, `JOB_PROCESSING_DELAY_SECONDS`, and `WORKER_HEARTBEAT_FILE` environment variables and enabled `decode_responses=True`.

- `worker/worker.py:28-32,47-48`
  Problem: The worker imported `signal` but did not handle shutdown signals, so it could not stop cleanly in containers.
  Fix: Added `SIGINT` and `SIGTERM` handlers that flip a `running` flag and allow the loop to exit gracefully.

- `worker/worker.py:35-44`
  Problem: The worker had no heartbeat mechanism, so there was no reliable way to implement a working container health check.
  Fix: Added heartbeat file updates on startup, after queue polls, and after job processing.

- `worker/worker.py:39-44`
  Problem: The worker jumped directly from queued work to completed work with no visible intermediate state.
  Fix: Added a `processing` status before the simulated work delay.

- `worker/worker.py:52-63`
  Problem: A Redis failure would crash the worker loop.
  Fix: Wrapped queue polling in `try/except redis.RedisError` and added a short retry delay.

- `worker/worker.py:54-59`
  Problem: During Docker verification, the worker consumed queue items but skipped status updates because the `brpop()` result was handled too narrowly.
  Fix: Accepted both `list` and `tuple` job payloads before reading `job[1]`.

- `worker/requirements.txt:1`
  Problem: The worker dependency was unpinned, which makes Docker builds less reproducible.
  Fix: Pinned `redis`.

- `frontend/app.js:6-13`
  Problem: The frontend hardcoded the API URL, did not expose host/timeout settings, and was not prepared for container binding.
  Fix: Added `API_URL`, `PORT`, `HOST`, and `REQUEST_TIMEOUT_MS` environment variables and built an `axios` client from them.

- `frontend/app.js:18-20`
  Problem: The frontend had no dedicated health endpoint for container health checks.
  Fix: Added `/health`, which returns a simple `200 OK` JSON response.

- `frontend/app.js:22-43`
  Problem: The frontend wrapper hid upstream API errors by replacing them with a generic `500`.
  Fix: Preserved upstream status codes and payloads when `axios` returns an HTTP error, and only fall back to a generic `500` for proxy/runtime failures.

- `frontend/app.js:46-47`
  Problem: The frontend listened only on a fixed port and did not bind explicitly for container use.
  Fix: Changed the listener to use `PORT` and `HOST`.

- `frontend/views/index.html:23-33`
  Problem: The browser UI assumed submission always succeeded and could render `Submitted: undefined` on failures.
  Fix: Added `res.ok` checks and displayed error details before using `data.job_id`.

- `frontend/views/index.html:35-45`
  Problem: The browser poller assumed status lookups always succeeded and could render `undefined` status values.
  Fix: Added `res.ok` checks before rendering job status and show an error message on failed lookups.

- `api/.dockerignore:1-5`
  Problem: The API build context could have copied `.env`, virtualenvs, or caches into the image.
  Fix: Added Docker ignore rules for secrets and local Python artifacts.

- `worker/.dockerignore:1-4`
  Problem: The worker build context could have copied local Python artifacts into the image.
  Fix: Added Docker ignore rules for virtualenvs and caches.

- `frontend/.dockerignore:1-4`
  Problem: The frontend build context could have copied local env files and `node_modules` into the image.
  Fix: Added Docker ignore rules for env files and Node artifacts.

- `api/Dockerfile:1-32`
  Problem: There was no production API image definition.
  Fix: Added a multi-stage Python image, non-root runtime user, and an HTTP health check.

- `worker/Dockerfile:1-31`
  Problem: There was no production worker image definition.
  Fix: Added a multi-stage Python image, non-root runtime user, and a heartbeat-based health check.

- `frontend/Dockerfile:1-24`
  Problem: There was no production frontend image definition.
  Fix: Added a multi-stage Node image, non-root runtime user, and an HTTP health check.

- `docker-compose.yml:1-89`
  Problem: There was no Compose definition for the full stack.
  Fix: Added a Compose stack with env-driven runtime configuration, health-gated dependencies, CPU and memory limits for every service, Redis kept off the host, a named internal network for service-to-service traffic, and a host-facing edge network for frontend and API port publishing.

- `.env.example:1-34`
  Problem: The repository did not document the variables required to run the Docker stack.
  Fix: Added placeholder/default values for images, network names, ports, Redis settings, queue settings, worker heartbeat, and resource limits.

- `README.md:1-153`
  Problem: The README only described the earlier manual-run state and did not explain how to bring the full stack up with Docker.
  Fix: Rewrote the README to cover prerequisites, env setup, Docker Compose startup, verification, shutdown, network layout, and manual fallback commands.
