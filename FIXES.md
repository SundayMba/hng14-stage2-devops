# Fixes So Far

This file documents only the bugs identified and fixed so far.

- `api/main.py:8-11`
  Problem: Redis connection was hardcoded to `localhost:6379`, which makes the API inflexible and breaks container or network-based deployments.
  Fix: Replaced the hardcoded values with `REDIS_HOST` and `REDIS_PORT` environment variables, with `localhost` and `6379` as defaults.

- `api/main.py:14-19`
  Problem: `POST /jobs` pushed the job ID into Redis before storing the initial job status. The worker could consume the job before its initial state existed.
  Fix: Changed the order so the API writes the `queued` status first, then pushes the job into the queue.

- `api/main.py:14-19`
  Problem: `POST /jobs` returned only `job_id` and used the default `200 OK` response for a create operation.
  Fix: Changed the endpoint to return `201 Created` and include both `job_id` and the initial `status`.

- `api/main.py:21-29`
  Problem: `GET /jobs/{job_id}` returned `{"error": "not found"}` with a `200 OK` response when the job did not exist.
  Fix: Replaced the plain return with `HTTPException(status_code=404, detail="not found")`.

- `api/main.py:11,21-29`
  Problem: The status lookup used `decode()` on the Redis result. After switching to decoded Redis responses, that call became invalid and Pylance reported it.
  Fix: Enabled `decode_responses=True` on the Redis client and returned the Redis status string directly without calling `decode()`.
