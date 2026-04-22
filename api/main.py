from fastapi import FastAPI, HTTPException, status as httpStatus
import redis
import uuid
import os

app = FastAPI()

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)


@app.post("/jobs", status_code=httpStatus.HTTP_201_CREATED)
def create_job():
    job_id = str(uuid.uuid4())
    r.hset(f"job:{job_id}", "status", "queued")
    r.lpush("job", job_id)
    return {"job_id": job_id, "status": "queued"}

@app.get("/jobs/{job_id}")
def get_job(job_id: str):
    job_status = r.hget(f"job:{job_id}", "status")
    if not job_status:
        raise HTTPException(
            status_code=httpStatus.HTTP_404_NOT_FOUND,
            detail="not found",
        )
    return {"job_id": job_id, "status": job_status}
