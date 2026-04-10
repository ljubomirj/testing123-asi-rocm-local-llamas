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
FIXED_MAX_TOKENS="${FIXED_MAX_TOKENS:-5000}"

# Model list can be overridden, comma-separated.
MODELS_CSV="${MODELS_CSV:-Qwen3.5-35B-A3B-IQ4,Qwen3.5-27B-Q4,Qwen3.5-9B-Q8,GLM-4.7-Flash-Q4}"

# Pilot ID selection from prior-empty GLM baseline outputs.
BASELINE_EMPTY_DIR="${BASELINE_EMPTY_DIR:-}"
BASELINE_EMPTY_MODEL="${BASELINE_EMPTY_MODEL:-GLM-4.7-Flash-Q4}"
PILOT_QUOTAS="${PILOT_QUOTAS:-7,7,6}"
PILOT_ID_TARGET="${PILOT_ID_TARGET:-20}"

# Optional explicit stop sequences as JSON list; empty => no explicit stop.
STOP_SEQUENCES_JSON="${STOP_SEQUENCES_JSON:-}"

if [[ ! -x "$SUBSET_SCRIPT" ]]; then
  echo "Missing executable script: $SUBSET_SCRIPT"
  exit 1
fi
if [[ ! -x "$SERVER_BIN" ]]; then
  echo "Missing llama-server binary: $SERVER_BIN"
  exit 1
fi

model_path_for() {
  case "$1" in
    "Qwen3.5-35B-A3B-IQ4") echo "$HOME/llama.cpp/models/Qwen3.5-35B-A3B-UD-IQ4_XS.gguf" ;;
    "Qwen3.5-27B-Q4")      echo "$HOME/llama.cpp/models/Qwen3.5-27B-UD-Q4_K_XL.gguf" ;;
    "Qwen3.5-9B-Q8")       echo "$HOME/llama.cpp/models/Qwen3.5-9B-UD-Q8_K_XL.gguf" ;;
    "GLM-4.7-Flash-Q4")    echo "$HOME/llama.cpp/models/GLM-4.7-Flash-UD-Q4_K_XL.gguf" ;;
    *)
      echo ""
      ;;
  esac
}

tuned_sampling_for() {
  local model_name="$1"
  if [[ "$model_name" == Qwen3.5-* ]]; then
    # Qwen thinking guidance: temp=0.6, top_p=0.95, top_k=20, min_p=0
    echo "0.6 0.95 20 0"
  elif [[ "$model_name" == "GLM-4.7-Flash-Q4" ]]; then
    # GLM docs mention agentic tasks around temp=0.7, top_p=1.0
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

pick_ids_file_if_missing() {
  if [[ -n "$BASELINE_EMPTY_DIR" ]]; then
    return 0
  fi
  local latest
  latest="$(ls -1dt "$ROOT_DIR"/benchmark_results_livecodebench_glm_baseline_* 2>/dev/null | head -n1 || true)"
  if [[ -z "$latest" ]]; then
    echo "Could not find baseline dir benchmark_results_livecodebench_glm_baseline_*"
    exit 1
  fi
  BASELINE_EMPTY_DIR="$latest/$BASELINE_EMPTY_MODEL"
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

case_already_completed() {
  local model_name="$1"
  local stage="$2"
  local case_name="$3"
  local model_case_dir="$4"

  [[ -f "$model_case_dir/scores_union_three_windows.txt" ]] || return 1
  [[ -f "$SUMMARY_CSV" ]] || return 1

  awk -F, -v model="$model_name" -v stage_name="$stage" -v case_name="$case_name" '
    NR > 1 && $1 == model && $2 == stage_name && $3 == case_name { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$SUMMARY_CSV"
}

is_better_case() {
  local cand_overall="$1"
  local cand_empty_out="$2"
  local cand_empty_code="$3"
  local best_overall="$4"
  local best_empty_out="$5"
  local best_empty_code="$6"

  python3 - <<PY
cand_overall = float("$cand_overall")
cand_empty_out = float("$cand_empty_out")
cand_empty_code = float("$cand_empty_code")
best_overall = float("$best_overall")
best_empty_out = float("$best_empty_out")
best_empty_code = float("$best_empty_code")

# Primary: pass@1 desc
# Tie-break 1: empty output rate asc
# Tie-break 2: empty code rate asc
if cand_overall > best_overall + 1e-12:
    print(1)
elif abs(cand_overall - best_overall) <= 1e-12 and cand_empty_out < best_empty_out - 1e-12:
    print(1)
elif abs(cand_overall - best_overall) <= 1e-12 and abs(cand_empty_out - best_empty_out) <= 1e-12 and cand_empty_code < best_empty_code - 1e-12:
    print(1)
else:
    print(0)
PY
}

run_case() {
  local model_name="$1"
  local model_safe="$2"
  local stage="$3"
  local case_name="$4"
  local reasoning_format="$5"
  local max_tokens="$6"
  local temp="$7"
  local top_p="$8"
  local top_k="$9"
  local min_p="${10}"

  local case_root="$RUN_ROOT/$model_safe/$stage/$case_name"
  local run_log="$case_root/run.log"
  local model_case_dir="$case_root/$model_name"

  mkdir -p "$case_root"

  if case_already_completed "$model_name" "$stage" "$case_name" "$model_case_dir"; then
    read -r rows overall empty_output_rate empty_code_rate < <(compute_metrics_line "$model_case_dir")
    echo "Skipping completed case: $model_name / $stage / $case_name" >&2
    echo "$rows $overall $empty_output_rate $empty_code_rate $case_root"
    return 0
  fi

  local elapsed
  local start_s=$SECONDS

  local -a env_args
  env_args=(
    "OPENAI_API_BASE=http://$HOST:$PORT/v1"
    "OPENAI_BASE_URL=http://$HOST:$PORT/v1"
    "OPENAI_TIMEOUT=$OPENAI_TIMEOUT"
    "MAX_TOKENS=$max_tokens"
    "TEMP=$temp"
    "TOP_P=$top_p"
    "N=1"
    "RESET_OUTPUT=1"
    "LOG_DIR=$case_root"
    "LCB_INCLUDE_QUESTION_IDS=$PILOT_IDS"
    "LCB_REASONING_FORMAT=$reasoning_format"
    "LCB_CHAT_TEMPLATE_KWARGS_JSON={\"enable_thinking\": true}"
    "LCB_QWEN_NO_THINK_HINT=0"
  )

  if [[ -n "$STOP_SEQUENCES_JSON" ]]; then
    env_args+=("LCB_STOP_SEQUENCES=$STOP_SEQUENCES_JSON")
  fi
  if [[ "$top_k" != "''" && -n "$top_k" ]]; then
    env_args+=("LCB_TOP_K=$top_k")
  fi
  if [[ "$min_p" != "''" && -n "$min_p" ]]; then
    env_args+=("LCB_MIN_P=$min_p")
  fi

  env "${env_args[@]}" \
    "$SUBSET_SCRIPT" "$model_name" | tee "$run_log" >&2

  elapsed=$((SECONDS - start_s))

  read -r rows overall empty_output_rate empty_code_rate < <(compute_metrics_line "$model_case_dir")

  echo "$model_name,$stage,$case_name,$reasoning_format,$max_tokens,$temp,$top_p,${top_k:-},${min_p:-},$elapsed,$rows,$overall,$empty_output_rate,$empty_code_rate,$case_root,$run_log" >> "$SUMMARY_CSV"

  echo "$rows $overall $empty_output_rate $empty_code_rate $case_root"
}

start_server_for_model() {
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

  if [[ -n "${CHAT_TEMPLATE_FILE:-}" ]]; then
    args+=(--chat-template-file "$CHAT_TEMPLATE_FILE")
  fi
  if [[ -n "${CTX_CHECKPOINTS:-}" ]]; then
    args+=(--ctx-checkpoints "$CTX_CHECKPOINTS")
  fi
  if [[ -n "${CHECKPOINT_EVERY_N_TOKENS:-}" ]]; then
    args+=(--checkpoint-every-n-tokens "$CHECKPOINT_EVERY_N_TOKENS")
  fi
  if [[ "${SWA_FULL:-0}" == "1" ]]; then
    args+=(--swa-full)
  fi

  "${args[@]}" >"$server_log" 2>&1 &
  SERVER_PID=$!

  if ! wait_for_server; then
    echo "Server failed to become ready for $model_name"
    tail -n 120 "$server_log" || true
    return 1
  fi
  return 0
}

stop_server() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  SERVER_PID=""
}

SERVER_PID=""
cleanup() {
  stop_server
}
trap cleanup EXIT INT TERM

pick_ids_file_if_missing
if [[ ! -d "$BASELINE_EMPTY_DIR" ]]; then
  echo "Baseline empty directory not found: $BASELINE_EMPTY_DIR"
  exit 1
fi

RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/benchmark_results_livecodebench_thinking_ab_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$RUN_ROOT"

SUMMARY_CSV="$RUN_ROOT/summary.csv"
if [[ ! -f "$SUMMARY_CSV" ]]; then
  echo "model,stage,case,reasoning_format,max_tokens,temp,top_p,top_k,min_p,total_seconds,rows,overall_pass_at_1,empty_output_rate,empty_code_rate,case_root,run_log" > "$SUMMARY_CSV"
fi

PILOT_IDS_FILE="$RUN_ROOT/pilot_question_ids.txt"
if [[ -f "$PILOT_IDS_FILE" ]]; then
  PILOT_IDS="$(paste -sd, "$PILOT_IDS_FILE")"
else
  PILOT_IDS="$(python3 - "$BASELINE_EMPTY_DIR" "$PILOT_QUOTAS" "$PILOT_ID_TARGET" <<'PY'
import json
import os
import sys

base = sys.argv[1]
quotas = [int(x) for x in sys.argv[2].split(',')]
target = int(sys.argv[3])
if len(quotas) != 3:
    raise SystemExit("PILOT_QUOTAS must be 3 comma-separated integers")

files = [
    "eval_all_2024-01-01_to_2024-02-29.json",
    "eval_all_2024-05-01_to_2024-06-30.json",
    "eval_all_2025-04-01_to_2025-05-31.json",
]

all_empties = []
chosen = []
for f, quota in zip(files, quotas):
    p = os.path.join(base, f)
    rows = json.load(open(p, "r"))
    empties = [
        str(r["question_id"])
        for r in rows
        if not ((r.get("output_list") or [""])[0] or "").strip()
    ]
    all_empties.extend(empties)
    chosen.extend(empties[:quota])

# Fill shortfalls with remaining empties in original order.
chosen_dedup = []
seen = set()
for q in chosen + all_empties:
    if q not in seen:
        seen.add(q)
        chosen_dedup.append(q)

final_ids = chosen_dedup[:target]
print(",".join(final_ids))
PY
)"
fi

if [[ -z "$PILOT_IDS" ]]; then
  echo "Could not determine pilot IDs from: $BASELINE_EMPTY_DIR"
  exit 1
fi
if [[ ! -f "$PILOT_IDS_FILE" ]]; then
  echo "$PILOT_IDS" | tr ',' '\n' > "$PILOT_IDS_FILE"
fi

MODEL_META="$RUN_ROOT/model_selection.txt"
{
  echo "BASELINE_EMPTY_DIR=$BASELINE_EMPTY_DIR"
  echo "PILOT_QUOTAS=$PILOT_QUOTAS"
  echo "PILOT_ID_TARGET=$PILOT_ID_TARGET"
  echo "PILOT_ID_COUNT=$(wc -l < "$PILOT_IDS_FILE")"
  echo "FIXED_MAX_TOKENS=$FIXED_MAX_TOKENS"
  echo "MODELS_CSV=$MODELS_CSV"
  echo "STOP_SEQUENCES_JSON=${STOP_SEQUENCES_JSON:-<none>}"
} > "$MODEL_META"

echo "Pilot root: $RUN_ROOT"
echo "Pilot IDs file: $PILOT_IDS_FILE"

echo "Using models: $MODELS_CSV"
IFS=',' read -r -a MODELS <<< "$MODELS_CSV"

for model_name in "${MODELS[@]}"; do
  model_name="$(echo "$model_name" | xargs)"
  [[ -z "$model_name" ]] && continue

  model_path="$(model_path_for "$model_name")"
  if [[ -z "$model_path" || ! -f "$model_path" ]]; then
    echo "Skipping model (path missing): $model_name -> $model_path"
    continue
  fi

  model_safe="${model_name//[^A-Za-z0-9._-]/_}"
  model_root="$RUN_ROOT/$model_safe"
  mkdir -p "$model_root"

  server_log="$model_root/server.log"
  echo ""
  echo "=== Starting model: $model_name ==="
  start_server_for_model "$model_name" "$model_path" "$server_log"

  # Stage A: reasoning format A/B (fixed max_tokens, baseline sampling)
  echo "--- Stage A: reasoning format A/B ---"
  best_format=""
  best_overall="-1"
  best_empty_out="1"
  best_empty_code="1"

  for fmt in deepseek none deepseek-legacy; do
    read -r rows overall empty_out empty_code _case_root < <(
      run_case "$model_name" "$model_safe" "A_reasoning" "$fmt" "$fmt" "$FIXED_MAX_TOKENS" "1.0" "0.95" "''" "''"
    )
    if [[ -z "$best_format" ]]; then
      best_format="$fmt"
      best_overall="$overall"
      best_empty_out="$empty_out"
      best_empty_code="$empty_code"
    else
      better="$(is_better_case "$overall" "$empty_out" "$empty_code" "$best_overall" "$best_empty_out" "$best_empty_code")"
      if [[ "$better" == "1" ]]; then
        best_format="$fmt"
        best_overall="$overall"
        best_empty_out="$empty_out"
        best_empty_code="$empty_code"
      fi
    fi
    echo "Stage A $model_name $fmt: pass@1=$overall empty_out=$empty_out empty_code=$empty_code rows=$rows"
  done

  echo "Selected best reasoning_format for $model_name: $best_format"
  best_max_tokens="$FIXED_MAX_TOKENS"
  echo "Selected max_tokens for $model_name: $best_max_tokens (fixed)"

  # Stage B: sampling A/B (best format + fixed max_tokens)
  echo "--- Stage C: sampling A/B ---"
  read -r rows overall empty_out empty_code _case_root < <(
    run_case "$model_name" "$model_safe" "C_sampling" "baseline" "$best_format" "$best_max_tokens" "1.0" "0.95" "''" "''"
  )
  echo "Stage C $model_name baseline: pass@1=$overall empty_out=$empty_out empty_code=$empty_code rows=$rows"

  read -r tune_temp tune_top_p tune_top_k tune_min_p < <(tuned_sampling_for "$model_name")
  read -r rows overall empty_out empty_code _case_root < <(
    run_case "$model_name" "$model_safe" "C_sampling" "tuned" "$best_format" "$best_max_tokens" "$tune_temp" "$tune_top_p" "$tune_top_k" "$tune_min_p"
  )
  echo "Stage C $model_name tuned: pass@1=$overall empty_out=$empty_out empty_code=$empty_code rows=$rows"

  {
    echo "model=$model_name"
    echo "best_reasoning_format=$best_format"
    echo "best_max_tokens=$best_max_tokens"
    echo "server_log=$server_log"
  } > "$model_root/selection.txt"

  stop_server
  echo "=== Completed model: $model_name ==="
done

echo ""
echo "Thinking A/B pilot complete."
echo "Root: $RUN_ROOT"
echo "Summary CSV: $SUMMARY_CSV"
echo "Pilot IDs: $PILOT_IDS_FILE"
