#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBSET_SCRIPT="$ROOT_DIR/scripts/livecodebench_run_subset.sh"
SERVER_BIN="${SERVER_BIN:-$HOME/llama.cpp/build-gigul2-hip-rocwmma/bin/llama-server}"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8081}"
DEVICE="${DEVICE:-ROCm0}"
CTX_SIZE="${CTX_SIZE:-150000}"
SERVER_MAX_TOKENS="${SERVER_MAX_TOKENS:-100000}"
OPENAI_TIMEOUT="${OPENAI_TIMEOUT:-1800}"
MAX_TOKENS="${MAX_TOKENS:-5000}"
MODEL_NAME="${MODEL_NAME:-Qwen3.5-27B-Q4}"
REASONING_FORMAT="${REASONING_FORMAT:-deepseek}"
PILOT_IDS_FILE="${PILOT_IDS_FILE:-$ROOT_DIR/benchmark_results_livecodebench_thinking_ab_20260311_170646/pilot_question_ids.txt}"

SYSTEM_APPEND_DEFAULT="Think briefly, then provide the final answer. If you find yourself spending too long reasoning, stop and return the best complete Python solution you can. Return only one Python code block."
FINAL_CONSTRAINT_DEFAULT="Return exactly one complete Python code block and nothing else. Do not output <think> tags."

if [[ ! -x "$SUBSET_SCRIPT" ]]; then
  echo "Missing executable script: $SUBSET_SCRIPT"
  exit 1
fi
if [[ ! -x "$SERVER_BIN" ]]; then
  echo "Missing llama-server binary: $SERVER_BIN"
  exit 1
fi
if [[ ! -f "$PILOT_IDS_FILE" ]]; then
  echo "Pilot IDs file not found: $PILOT_IDS_FILE"
  exit 1
fi

model_path_for() {
  case "$1" in
    "Qwen3.5-35B-A3B-IQ4") echo "$HOME/llama.cpp/models/Qwen3.5-35B-A3B-UD-IQ4_XS.gguf" ;;
    "Qwen3.5-27B-Q4")      echo "$HOME/llama.cpp/models/Qwen3.5-27B-UD-Q4_K_XL.gguf" ;;
    "Qwen3.5-9B-Q8")       echo "$HOME/llama.cpp/models/Qwen3.5-9B-UD-Q8_K_XL.gguf" ;;
    "GLM-4.7-Flash-Q4")    echo "$HOME/llama.cpp/models/GLM-4.7-Flash-UD-Q4_K_XL.gguf" ;;
    *) echo "" ;;
  esac
}

tuned_sampling_for() {
  local model_name="$1"
  if [[ "$model_name" == Qwen3.5-* ]]; then
    echo "0.6 0.95 20 0"
  elif [[ "$model_name" == "GLM-4.7-Flash-Q4" ]]; then
    echo "0.7 1.0 '' ''"
  else
    echo "1.0 0.95 '' ''"
  fi
}

wait_for_server() {
  local url="http://$HOST:$PORT/v1/models"
  for _ in $(seq 1 180); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

compute_metrics_line() {
  local model_case_dir="$1"
  python3 - "$model_case_dir" <<'PY'
import json
import os
import sys

model_case_dir = sys.argv[1]
files = [
    "eval_all_2024-01-01_to_2024-02-29.json",
    "eval_all_2024-05-01_to_2024-06-30.json",
    "eval_all_2025-04-01_to_2025-05-31.json",
]
rows = []
for f in files:
    p = os.path.join(model_case_dir, f)
    if os.path.exists(p):
        with open(p, "r") as fh:
            rows.extend(json.load(fh))

if not rows:
    print("0 0.0 1.0 1.0")
    raise SystemExit(0)

n = len(rows)
overall = sum(float(r.get("pass@1", 0.0)) for r in rows) / n
empty_output = 0
empty_code = 0
for r in rows:
    out0 = ((r.get("output_list") or [""])[0] or "").strip()
    code0 = ((r.get("code_list") or [""])[0] or "").strip()
    if not out0:
        empty_output += 1
    if not code0:
        empty_code += 1

print(f"{n} {overall:.6f} {empty_output/n:.6f} {empty_code/n:.6f}")
PY
}

start_server() {
  local model_name="$1"
  local model_path="$2"
  local server_log="$3"

  local -a args
  args=(
    "$SERVER_BIN"
    --device "$DEVICE"
    --gpu-layers all
    --ctx-size "$CTX_SIZE"
    --host "$HOST"
    --port "$PORT"
    --model "$model_path"
    --alias "$model_name"
    --temp "1.0"
    --top-p "0.95"
    --top-k "0"
    --min-p "0"
    --seed "3407"
    --flash-attn on
    --cache-type-k q8_0
    --cache-type-v q8_0
    --jinja
    --reasoning-format auto
    --reasoning-budget -1
    --cache-ram "32768"
    --cache-reuse "512"
    --cache-prompt
    --parallel "1"
    --batch-size "2048"
    --ubatch-size "512"
    --threads-batch "10"
    --threads "10"
    --mlock
    --no-mmap
    --kv-unified
    --n-predict "$SERVER_MAX_TOKENS"
  )

  "${args[@]}" >"$server_log" 2>&1 &
  SERVER_PID=$!

  if ! wait_for_server; then
    echo "Server failed to become ready for $model_name"
    tail -n 120 "$server_log" || true
    return 1
  fi
}

stop_server() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  SERVER_PID=""
}

run_case() {
  local case_name="$1"
  local temp="$2"
  local top_p="$3"
  local top_k="$4"
  local min_p="$5"
  local system_append="$6"
  local final_constraint="$7"

  local case_root="$RUN_ROOT/$MODEL_SAFE/$case_name"
  local run_log="$case_root/run.log"
  local model_case_dir="$case_root/$MODEL_NAME"
  mkdir -p "$case_root"

  local -a env_args
  env_args=(
    "OPENAI_API_BASE=http://$HOST:$PORT/v1"
    "OPENAI_BASE_URL=http://$HOST:$PORT/v1"
    "OPENAI_TIMEOUT=$OPENAI_TIMEOUT"
    "MAX_TOKENS=$MAX_TOKENS"
    "TEMP=$temp"
    "TOP_P=$top_p"
    "N=1"
    "RESET_OUTPUT=1"
    "LOG_DIR=$case_root"
    "LCB_INCLUDE_QUESTION_IDS=$PILOT_IDS"
    "LCB_REASONING_FORMAT=$REASONING_FORMAT"
    "LCB_CHAT_TEMPLATE_KWARGS_JSON={\"enable_thinking\": true}"
    "LCB_REPEAT_LAST_N=0"
    "LCB_REPEAT_PENALTY=1.0"
    "LCB_PRESENCE_PENALTY=0.0"
    "LCB_FREQUENCY_PENALTY=0.0"
    "LCB_DRY_MULTIPLIER=0.0"
    "LCB_DRY_PENALTY_LAST_N=0"
  )

  if [[ "$top_k" != "''" && -n "$top_k" ]]; then
    env_args+=("LCB_TOP_K=$top_k")
  fi
  if [[ "$min_p" != "''" && -n "$min_p" ]]; then
    env_args+=("LCB_MIN_P=$min_p")
  fi
  if [[ -n "$system_append" ]]; then
    env_args+=("LCB_SYSTEM_MESSAGE_APPEND=$system_append")
  fi
  if [[ -n "$final_constraint" ]]; then
    env_args+=("LCB_FINAL_ANSWER_CONSTRAINT=$final_constraint")
  fi

  local start_s=$SECONDS
  env "${env_args[@]}" \
    "$SUBSET_SCRIPT" "$MODEL_NAME" | tee "$run_log"
  local elapsed=$((SECONDS - start_s))

  read -r rows overall empty_output_rate empty_code_rate < <(compute_metrics_line "$model_case_dir")
  echo "$MODEL_NAME,$case_name,$REASONING_FORMAT,$MAX_TOKENS,$temp,$top_p,${top_k:-},${min_p:-},$elapsed,$rows,$overall,$empty_output_rate,$empty_code_rate,$case_root,$run_log" >> "$SUMMARY_CSV"
}

SERVER_PID=""
trap stop_server EXIT INT TERM

MODEL_PATH="$(model_path_for "$MODEL_NAME")"
if [[ -z "$MODEL_PATH" || ! -f "$MODEL_PATH" ]]; then
  echo "Model path missing for $MODEL_NAME: $MODEL_PATH"
  exit 1
fi

MODEL_SAFE="${MODEL_NAME//[^A-Za-z0-9._-]/_}"
RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/benchmark_results_livecodebench_thinking_penalty_prompt_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$RUN_ROOT/$MODEL_SAFE"
SUMMARY_CSV="$RUN_ROOT/summary.csv"
echo "model,case,reasoning_format,max_tokens,temp,top_p,top_k,min_p,total_seconds,rows,overall_pass_at_1,empty_output_rate,empty_code_rate,case_root,run_log" > "$SUMMARY_CSV"

PILOT_IDS="$(paste -sd, "$PILOT_IDS_FILE")"
if [[ -z "$PILOT_IDS" ]]; then
  echo "Pilot IDs file is empty: $PILOT_IDS_FILE"
  exit 1
fi

read -r TUNE_TEMP TUNE_TOP_P TUNE_TOP_K TUNE_MIN_P < <(tuned_sampling_for "$MODEL_NAME")

{
  echo "MODEL_NAME=$MODEL_NAME"
  echo "MODEL_PATH=$MODEL_PATH"
  echo "PILOT_IDS_FILE=$PILOT_IDS_FILE"
  echo "REASONING_FORMAT=$REASONING_FORMAT"
  echo "MAX_TOKENS=$MAX_TOKENS"
} > "$RUN_ROOT/$MODEL_SAFE/selection.txt"

SERVER_LOG="$RUN_ROOT/$MODEL_SAFE/server.log"
echo "Run root: $RUN_ROOT"
echo "Model: $MODEL_NAME"
echo "Pilot IDs file: $PILOT_IDS_FILE"
echo "Reasoning format: $REASONING_FORMAT"

start_server "$MODEL_NAME" "$MODEL_PATH" "$SERVER_LOG"

run_case "no_penalties_only" "$TUNE_TEMP" "$TUNE_TOP_P" "$TUNE_TOP_K" "$TUNE_MIN_P" "" ""
run_case "no_penalties_plus_prompt" "$TUNE_TEMP" "$TUNE_TOP_P" "$TUNE_TOP_K" "$TUNE_MIN_P" "$SYSTEM_APPEND_DEFAULT" "$FINAL_CONSTRAINT_DEFAULT"

stop_server

echo "Pilot complete."
echo "Root: $RUN_ROOT"
echo "Summary CSV: $SUMMARY_CSV"
