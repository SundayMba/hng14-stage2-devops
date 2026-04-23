#!/usr/bin/env bash

set -euo pipefail

ENV_FILE="${1:-.env}"

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

cleanup() {
  docker compose --env-file "${ENV_FILE}" down -v --remove-orphans
}

trap cleanup EXIT

wait_for_http() {
  local url="$1"
  local timeout_seconds="$2"
  local started_at
  started_at="$(date +%s)"

  while true; do
    if curl -fsS "${url}" >/dev/null; then
      return 0
    fi

    if (( "$(date +%s)" - started_at >= timeout_seconds )); then
      echo "Timed out waiting for ${url}" >&2
      return 1
    fi

    sleep 2
  done
}

extract_json_field() {
  local field_name="$1"
  python3 -c "import json, sys; print(json.load(sys.stdin)['${field_name}'])"
}

compose_args=(--env-file "${ENV_FILE}" up -d)
if [[ "${INTEGRATION_NO_BUILD:-false}" == "true" ]]; then
  compose_args+=(--no-build)
fi

docker compose "${compose_args[@]}"
wait_for_http "http://127.0.0.1:${FRONTEND_HOST_PORT}/" 60

job_payload="$(curl -fsS -X POST "http://127.0.0.1:${FRONTEND_HOST_PORT}/submit")"
job_id="$(printf '%s' "${job_payload}" | extract_json_field "job_id")"

started_at="$(date +%s)"
while true; do
  status_payload="$(curl -fsS "http://127.0.0.1:${FRONTEND_HOST_PORT}/status/${job_id}")"
  job_status="$(printf '%s' "${status_payload}" | extract_json_field "status")"

  if [[ "${job_status}" == "completed" ]]; then
    echo "Integration test passed for job ${job_id}"
    break
  fi

  if (( "$(date +%s)" - started_at >= 90 )); then
    echo "Job ${job_id} did not complete in time" >&2
    exit 1
  fi

  sleep 2
done
