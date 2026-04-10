#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

export OPENAI_API_BASE="${OPENAI_API_BASE:-https://api.z.ai/api/paas/v4}"
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-$OPENAI_API_BASE}"
export OPENAI_KEY="${OPENAI_KEY:-${ZAI_API_KEY:-${ZAI_ANTHROPIC_AUTH_TOKEN:-}}}"

if [[ -z "${OPENAI_KEY}" ]]; then
  echo "Missing OPENAI_KEY, ZAI_API_KEY, or ZAI_ANTHROPIC_AUTH_TOKEN"
  exit 1
fi

export MODEL_NAME="${MODEL_NAME:-pony-alpha-2}"
export LOG_DIR="${LOG_DIR:-$ROOT_DIR/benchmark_results_livecodebench_zai_pony_alpha2_${TIMESTAMP}}"
export RESET_OUTPUT="${RESET_OUTPUT:-1}"
export N="${N:-1}"
export TEMP="${TEMP:-0.0}"
export TOP_P="${TOP_P:-1.0}"
export MAX_TOKENS="${MAX_TOKENS:-10000}"
export OPENAI_TIMEOUT="${OPENAI_TIMEOUT:-1800}"

mkdir -p "$LOG_DIR"

echo "Run root: $LOG_DIR"
echo "API base: $OPENAI_API_BASE"
echo "Model: $MODEL_NAME"
echo "n=$N temp=$TEMP top_p=$TOP_P max_tokens=$MAX_TOKENS openai_timeout=$OPENAI_TIMEOUT"

"$ROOT_DIR/scripts/livecodebench_run_subset.sh" "$MODEL_NAME" | tee "$LOG_DIR/launch.log"
