#!/usr/bin/env bash
set -euo pipefail

# Simple profiler driver for SGLang server + bench.
# Usage:
#   BASE_URL=http://127.0.0.1:8000 \
#   PROFILE_DIR=/home/ljubomir/tmp/sglang_profile \
#   PROFILE_STEPS=10 \
#   BENCH_MAX_TOKENS=200 BENCH_PROMPT_LEN=150 \
#   ./scripts/profile_decode.sh

BASE_URL=${BASE_URL:-http://127.0.0.1:8000}
PROFILE_DIR=${PROFILE_DIR:-/home/ljubomir/tmp/sglang_profile}
PROFILE_STEPS=${PROFILE_STEPS:-10}
PROFILE_BY_STAGE=${PROFILE_BY_STAGE:-0}
PROFILE_ACTIVITIES=${PROFILE_ACTIVITIES:-CPU,GPU}

MODEL_NAME=${MODEL_NAME:-glm-4.7-flash}
BENCH_RUNS=${BENCH_RUNS:-1}

mkdir -p "$PROFILE_DIR"
PROFILE_OUT="$PROFILE_DIR/$(date +%s)"
mkdir -p "$PROFILE_OUT"

IFS="," read -r -a _acts <<< "$PROFILE_ACTIVITIES"
ACT_JSON="["
for a in "${_acts[@]}"; do
  a_trim=$(echo "$a" | xargs)
  if [[ -n "$a_trim" ]]; then
    if [[ "$ACT_JSON" != "[" ]]; then
      ACT_JSON+=",";
    fi
    ACT_JSON+="\"$a_trim\""
  fi
done
ACT_JSON+="]"

echo "Starting profile: $PROFILE_OUT"
curl -s -X POST "$BASE_URL/start_profile" \
  -H "Content-Type: application/json" \
  -d "{\"output_dir\": \"$PROFILE_OUT\", \"num_steps\": $PROFILE_STEPS, \"activities\": $ACT_JSON, \"profile_by_stage\": $PROFILE_BY_STAGE}" \
  >/dev/null

echo "Running bench..."
BENCH_MAX_TOKENS=${BENCH_MAX_TOKENS:-200} \
BENCH_PROMPT_LEN=${BENCH_PROMPT_LEN:-150} \
python3 bench_sglang.py --base "$BASE_URL" --model "$MODEL_NAME" --runs "$BENCH_RUNS"

echo "Stopping profile (flush)..."
curl -s -X POST "$BASE_URL/stop_profile" >/dev/null || true

echo "Profile traces saved under: $PROFILE_OUT"
echo "Open the .json trace in Chrome tracing (chrome://tracing) or TensorBoard profiler."
