import os
import signal
import time
from pathlib import Path

import redis

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_DB = int(os.getenv("REDIS_DB", "0"))
JOB_QUEUE_NAME = os.getenv("JOB_QUEUE_NAME", "job")
JOB_PROCESSING_DELAY_SECONDS = float(
    os.getenv("JOB_PROCESSING_DELAY_SECONDS", "2"),
)
WORKER_HEARTBEAT_FILE = Path(
    os.getenv("WORKER_HEARTBEAT_FILE", "/tmp/worker-heartbeat"),
)

r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    db=REDIS_DB,
    decode_responses=True,
)
running = True


def handle_shutdown(signum, frame):
    global running
    del frame
    print(f"Received signal {signum}, shutting down worker")
    running = False


def write_heartbeat():
    WORKER_HEARTBEAT_FILE.write_text(str(time.time()), encoding="ascii")


def process_job(job_id):
    print(f"Processing job {job_id}")
    r.hset(f"job:{job_id}", "status", "processing")
    time.sleep(JOB_PROCESSING_DELAY_SECONDS)
    r.hset(f"job:{job_id}", "status", "completed")
    print(f"Done: {job_id}")


signal.signal(signal.SIGINT, handle_shutdown)
signal.signal(signal.SIGTERM, handle_shutdown)

write_heartbeat()

while running:
    try:
        job = r.brpop(JOB_QUEUE_NAME, timeout=5)
        write_heartbeat()
        if not isinstance(job, (list, tuple)) or len(job) < 2:
            continue
        job_id = str(job[1])
        process_job(job_id)
        write_heartbeat()
    except redis.RedisError as err:
        print(f"Redis error: {err}")
        time.sleep(1)

print("Worker stopped")
