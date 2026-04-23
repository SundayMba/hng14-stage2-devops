from unittest.mock import Mock

import redis
from fastapi.testclient import TestClient

from api import main


client = TestClient(main.app)


def test_create_job_queues_new_job(monkeypatch):
    redis_client = Mock()
    monkeypatch.setattr(main, "r", redis_client)

    response = client.post("/jobs")

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "queued"
    assert "job_id" in body
    redis_client.hset.assert_called_once_with(
        f"job:{body['job_id']}",
        "status",
        "queued",
    )
    redis_client.lpush.assert_called_once_with(main.JOB_QUEUE_NAME, body["job_id"])


def test_get_job_returns_not_found_when_missing(monkeypatch):
    redis_client = Mock()
    redis_client.hget.return_value = None
    monkeypatch.setattr(main, "r", redis_client)

    response = client.get("/jobs/missing-job")

    assert response.status_code == 404
    assert response.json()["detail"] == "not found"


def test_get_job_returns_status_when_present(monkeypatch):
    redis_client = Mock()
    redis_client.hget.return_value = "completed"
    monkeypatch.setattr(main, "r", redis_client)

    response = client.get("/jobs/test-job")

    assert response.status_code == 200
    assert response.json() == {"job_id": "test-job", "status": "completed"}


def test_healthcheck_returns_service_unavailable_when_redis_fails(monkeypatch):
    redis_client = Mock()
    redis_client.ping.side_effect = redis.RedisError("down")
    monkeypatch.setattr(main, "r", redis_client)

    response = client.get("/health")

    assert response.status_code == 503
    assert response.json()["detail"] == "redis unavailable"
