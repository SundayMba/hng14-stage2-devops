#!/usr/bin/env bash

set -euo pipefail

ENV_FILE="${1:-.env}"
INTEGRATION_STARTUP_TIMEOUT_SECONDS="${INTEGRATION_STARTUP_TIMEOUT_SECONDS:-60}"
INTEGRATION_JOB_TIMEOUT_SECONDS="${INTEGRATION_JOB_TIMEOUT_SECONDS:-90}"

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

cleanup() {
  docker compose --env-file "${ENV_FILE}" down -v --remove-orphans
}

if [[ "${INTEGRATION_SKIP_CLEANUP:-false}" != "true" ]]; then
  trap cleanup EXIT
fi

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

if [[ "${INTEGRATION_SKIP_COMPOSE_UP:-false}" != "true" ]]; then
  docker compose "${compose_args[@]}"
fi
wait_for_http "http://127.0.0.1:${FRONTEND_HOST_PORT}/" "${INTEGRATION_STARTUP_TIMEOUT_SECONDS}"

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

  if (( "$(date +%s)" - started_at >= INTEGRATION_JOB_TIMEOUT_SECONDS )); then
    echo "Job ${job_id} did not complete in time" >&2
    exit 1
  fi

  sleep 2
done
