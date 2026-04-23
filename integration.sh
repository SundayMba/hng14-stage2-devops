#!/usr/bin/env bash

set -euo pipefail

export INTEGRATION_STARTUP_TIMEOUT_SECONDS="${INTEGRATION_STARTUP_TIMEOUT_SECONDS:-60}"
export INTEGRATION_JOB_TIMEOUT_SECONDS="${INTEGRATION_JOB_TIMEOUT_SECONDS:-90}"

exec "$(dirname "$0")/scripts/integration-test.sh" "${1:-.env}"
