import os
import uuid

import redis
from fastapi import FastAPI, HTTPException, status as http_status

app = FastAPI()

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_DB = int(os.getenv("REDIS_DB", "0"))
JOB_QUEUE_NAME = os.getenv("JOB_QUEUE_NAME", "job")

r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    db=REDIS_DB,
    decode_responses=True,
)


@app.get("/health")
def healthcheck():
    try:
        r.ping()
    except redis.RedisError as err:
        raise HTTPException(
            status_code=http_status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="redis unavailable",
        ) from err
    return {"status": "ok"}


@app.post("/jobs", status_code=http_status.HTTP_201_CREATED)
def create_job():
    job_id = str(uuid.uuid4())
    print(f"Creating job {job_id}")
    r.hset(f"job:{job_id}", "status", "queued")
    r.lpush(JOB_QUEUE_NAME, job_id)
    return {"job_id": job_id, "status": "queued"}


@app.get("/jobs/{job_id}")
def get_job(job_id: str):
    job_status = r.hget(f"job:{job_id}", "status")
    if not job_status:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="not found",
        )
    return {"job_id": job_id, "status": job_status}
