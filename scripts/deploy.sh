#!/usr/bin/env bash

set -euo pipefail

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
}

container_exists() {
  local name="$1"
  docker ps -a --format '{{.Names}}' | grep -Fxq "${name}"
}

container_running() {
  local name="$1"
  docker ps --format '{{.Names}}' | grep -Fxq "${name}"
}

wait_for_health() {
  local container_name="$1"
  local timeout_seconds="${2:-60}"
  local started_at
  local status
  started_at="$(date +%s)"

  while true; do
    status="$(
      docker inspect --format \
        '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
        "${container_name}" 2>/dev/null || true
    )"

    if [[ "${status}" == "healthy" || "${status}" == "running" ]]; then
      return 0
    fi

    if [[ "${status}" == "unhealthy" ]]; then
      echo "${container_name} reported unhealthy" >&2
      return 1
    fi

    if (( "$(date +%s)" - started_at >= timeout_seconds )); then
      echo "Timed out waiting for ${container_name} to become healthy" >&2
      return 1
    fi

    sleep 2
  done
}

ensure_network() {
  local name="$1"
  local internal="$2"
  if docker network inspect "${name}" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "${internal}" == "true" ]]; then
    docker network create --internal "${name}" >/dev/null
  else
    docker network create "${name}" >/dev/null
  fi
}

connect_network() {
  local network_name="$1"
  local container_name="$2"
  local alias_name="${3:-}"

  if docker inspect "${container_name}" --format '{{json .NetworkSettings.Networks}}' \
    | grep -q "\"${network_name}\""; then
    return 0
  fi

  if [[ -n "${alias_name}" ]]; then
    docker network connect --alias "${alias_name}" "${network_name}" "${container_name}" >/dev/null
    return 0
  fi

  docker network connect "${network_name}" "${container_name}" >/dev/null
}

start_redis() {
  if container_exists "${DEPLOY_REDIS_CONTAINER_NAME}"; then
    if ! container_running "${DEPLOY_REDIS_CONTAINER_NAME}"; then
      docker start "${DEPLOY_REDIS_CONTAINER_NAME}" >/dev/null
    fi
  else
    docker run -d \
      --name "${DEPLOY_REDIS_CONTAINER_NAME}" \
      --network "${DOCKER_INTERNAL_NETWORK_NAME}" \
      --network-alias "${REDIS_HOST}" \
      --restart unless-stopped \
      --health-cmd "redis-cli -p ${REDIS_PORT} ping | grep PONG" \
      --health-interval 10s \
      --health-timeout 3s \
      --health-retries 5 \
      "${REDIS_IMAGE}" >/dev/null
  fi

  wait_for_health "${DEPLOY_REDIS_CONTAINER_NAME}" 60
}

start_api_container() {
  local container_name="$1"
  local publish_port="$2"
  local alias_name="$3"
  local args=(
    docker run -d
    --name "${container_name}"
    --network "${DOCKER_INTERNAL_NETWORK_NAME}"
    --restart unless-stopped
  )

  docker rm -f "${container_name}" >/dev/null 2>&1 || true

  if [[ -n "${publish_port}" ]]; then
    args+=(-p "${API_BIND_ADDRESS}:${publish_port}:${API_PORT}")
  fi
  if [[ -n "${alias_name}" ]]; then
    args+=(--network-alias "${alias_name}")
  fi

  args+=(
    -e API_PORT="${API_PORT}"
    -e REDIS_HOST="${REDIS_HOST}"
    -e REDIS_PORT="${REDIS_PORT}"
    -e REDIS_DB="${REDIS_DB}"
    -e JOB_QUEUE_NAME="${JOB_QUEUE_NAME}"
    "${API_IMAGE}"
  )

  "${args[@]}" >/dev/null
  connect_network "${DOCKER_EDGE_NETWORK_NAME}" "${container_name}"
  wait_for_health "${container_name}" 60
}

roll_api() {
  local stable_name="${DEPLOY_API_CONTAINER_NAME}"
  local candidate_name="${stable_name}-candidate"
  local backup_name="${stable_name}-backup"

  if container_exists "${stable_name}"; then
    if ! start_api_container "${candidate_name}" "" ""; then
      docker rm -f "${candidate_name}" >/dev/null 2>&1 || true
      echo "API candidate failed health checks, leaving existing API running" >&2
      return 1
    fi

    docker rm -f "${backup_name}" >/dev/null 2>&1 || true
    docker rename "${stable_name}" "${backup_name}"
    docker stop "${backup_name}" >/dev/null

    if ! start_api_container "${stable_name}" "${API_HOST_PORT}" "api"; then
      docker rm -f "${stable_name}" >/dev/null 2>&1 || true
      docker rename "${backup_name}" "${stable_name}"
      docker start "${stable_name}" >/dev/null
      docker rm -f "${candidate_name}" >/dev/null 2>&1 || true
      echo "Replacement API failed health checks, restored previous API container" >&2
      return 1
    fi

    docker rm -f "${backup_name}" >/dev/null 2>&1 || true
    docker rm -f "${candidate_name}" >/dev/null 2>&1 || true
    return 0
  fi

  start_api_container "${stable_name}" "${API_HOST_PORT}" "api"
}

start_worker_candidate() {
  local candidate_name="${DEPLOY_WORKER_CONTAINER_NAME}-candidate"
  docker rm -f "${candidate_name}" >/dev/null 2>&1 || true
  docker run -d \
    --name "${candidate_name}" \
    --network "${DOCKER_INTERNAL_NETWORK_NAME}" \
    --restart unless-stopped \
    -e REDIS_HOST="${REDIS_HOST}" \
    -e REDIS_PORT="${REDIS_PORT}" \
    -e REDIS_DB="${REDIS_DB}" \
    -e JOB_QUEUE_NAME="${JOB_QUEUE_NAME}" \
    -e JOB_PROCESSING_DELAY_SECONDS="${JOB_PROCESSING_DELAY_SECONDS}" \
    -e WORKER_HEARTBEAT_FILE="${WORKER_HEARTBEAT_FILE}" \
    "${WORKER_IMAGE}" >/dev/null
  wait_for_health "${candidate_name}" 60
}

roll_worker() {
  local stable_name="${DEPLOY_WORKER_CONTAINER_NAME}"
  local candidate_name="${stable_name}-candidate"

  if ! start_worker_candidate; then
    docker rm -f "${candidate_name}" >/dev/null 2>&1 || true
    if container_exists "${stable_name}"; then
      echo "Worker candidate failed health checks, leaving existing worker running" >&2
    fi
    return 1
  fi

  docker rm -f "${stable_name}" >/dev/null 2>&1 || true
  docker rename "${candidate_name}" "${stable_name}"
}

start_frontend_container() {
  local container_name="$1"
  local publish_port="$2"
  local args=(
    docker run -d
    --name "${container_name}"
    --network "${DOCKER_INTERNAL_NETWORK_NAME}"
    --restart unless-stopped
  )

  docker rm -f "${container_name}" >/dev/null 2>&1 || true

  if [[ -n "${publish_port}" ]]; then
    args+=(-p "${FRONTEND_BIND_ADDRESS}:${publish_port}:${FRONTEND_PORT}")
  fi

  args+=(
    -e API_URL="http://api:${API_PORT}"
    -e PORT="${FRONTEND_PORT}"
    -e HOST="${FRONTEND_HOST}"
    -e REQUEST_TIMEOUT_MS="${FRONTEND_REQUEST_TIMEOUT_MS}"
    "${FRONTEND_IMAGE}"
  )

  "${args[@]}" >/dev/null
  connect_network "${DOCKER_EDGE_NETWORK_NAME}" "${container_name}"
  wait_for_health "${container_name}" 60
}

roll_frontend() {
  local stable_name="${DEPLOY_FRONTEND_CONTAINER_NAME}"
  local candidate_name="${stable_name}-candidate"
  local backup_name="${stable_name}-backup"

  if container_exists "${stable_name}"; then
    if ! start_frontend_container "${candidate_name}" ""; then
      docker rm -f "${candidate_name}" >/dev/null 2>&1 || true
      echo "Frontend candidate failed health checks, leaving existing frontend running" >&2
      return 1
    fi

    docker rm -f "${backup_name}" >/dev/null 2>&1 || true
    docker rename "${stable_name}" "${backup_name}"
    docker stop "${backup_name}" >/dev/null

    if ! start_frontend_container "${stable_name}" "${FRONTEND_HOST_PORT}"; then
      docker rm -f "${stable_name}" >/dev/null 2>&1 || true
      docker rename "${backup_name}" "${stable_name}"
      docker start "${stable_name}" >/dev/null
      docker rm -f "${candidate_name}" >/dev/null 2>&1 || true
      echo "Replacement frontend failed health checks, restored previous frontend container" >&2
      return 1
    fi

    docker rm -f "${backup_name}" >/dev/null 2>&1 || true
    docker rm -f "${candidate_name}" >/dev/null 2>&1 || true
    return 0
  fi

  start_frontend_container "${stable_name}" "${FRONTEND_HOST_PORT}"
}

require_env DOCKER_INTERNAL_NETWORK_NAME
require_env DOCKER_EDGE_NETWORK_NAME
require_env REDIS_IMAGE
require_env API_IMAGE
require_env WORKER_IMAGE
require_env FRONTEND_IMAGE
require_env REDIS_HOST
require_env REDIS_PORT
require_env REDIS_DB
require_env JOB_QUEUE_NAME
require_env JOB_PROCESSING_DELAY_SECONDS
require_env WORKER_HEARTBEAT_FILE
require_env API_PORT
require_env API_BIND_ADDRESS
require_env API_HOST_PORT
require_env FRONTEND_PORT
require_env FRONTEND_HOST
require_env FRONTEND_BIND_ADDRESS
require_env FRONTEND_HOST_PORT
require_env FRONTEND_REQUEST_TIMEOUT_MS
require_env DEPLOY_REDIS_CONTAINER_NAME
require_env DEPLOY_API_CONTAINER_NAME
require_env DEPLOY_WORKER_CONTAINER_NAME
require_env DEPLOY_FRONTEND_CONTAINER_NAME

ensure_network "${DOCKER_INTERNAL_NETWORK_NAME}" "true"
ensure_network "${DOCKER_EDGE_NETWORK_NAME}" "false"

start_redis
roll_api
roll_worker
roll_frontend
