import os
import signal
import time

import redis


REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
running = True


def handle_shutdown(signum, frame):
    global running
    del frame
    print(f"Received signal {signum}, shutting down worker")
    running = False


def process_job(job_id):
    print(f"Processing job {job_id}")
    r.hset(f"job:{job_id}", "status", "processing")
    time.sleep(2)  # simulate work
    r.hset(f"job:{job_id}", "status", "completed")
    print(f"Done: {job_id}")


signal.signal(signal.SIGINT, handle_shutdown)
signal.signal(signal.SIGTERM, handle_shutdown)


while running:
    try:
        job = r.brpop("job", timeout=5)
        if not isinstance(job, list) or len(job) < 2:
            continue
        job_id = str(job[1])
        process_job(job_id)
    except redis.RedisError as err:
        print(f"Redis error: {err}")
        time.sleep(1)

print("Worker stopped")
