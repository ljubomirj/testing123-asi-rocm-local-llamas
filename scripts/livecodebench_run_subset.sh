#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LCB_DIR="${LCB_DIR:-$ROOT_DIR/LiveCodeBench}"

MODEL_NAME="${1:-${MODEL_NAME:-}}"
if [[ -z "$MODEL_NAME" ]]; then
  echo "Usage: $0 <model-name-from-lm_styles.py>"
  exit 1
fi

if [[ ! -d "$LCB_DIR" ]]; then
  echo "LiveCodeBench directory not found: $LCB_DIR"
  exit 1
fi

API_BASE="${OPENAI_API_BASE:-${OPENAI_BASE_URL:-http://127.0.0.1:8081/v1}}"
export OPENAI_API_BASE="$API_BASE"
export OPENAI_BASE_URL="$API_BASE"
export OPENAI_KEY="${OPENAI_KEY:-dummy}"

RELEASE_VERSION="${RELEASE_VERSION:-release_v6}"
N="${N:-1}"
TEMP="${TEMP:-0.0}"
TOP_P="${TOP_P:-1.0}"
MAX_TOKENS="${MAX_TOKENS:-100000}"
OPENAI_TIMEOUT="${OPENAI_TIMEOUT:-1200}"
NUM_PROCESS_EVALUATE="${NUM_PROCESS_EVALUATE:-12}"

WINDOWS=(
  "2024-01-01 2024-02-29"
  "2024-05-01 2024-06-30"
  "2025-04-01 2025-05-31"
)
WINDOW_LIMITS=(36 44 12)

LOG_ROOT="${LOG_DIR:-$ROOT_DIR/benchmark_results_livecodebench_subset}"
MODEL_SAFE="${MODEL_NAME//[^A-Za-z0-9._-]/_}"
RUN_DIR="$LOG_ROOT/$MODEL_SAFE"
mkdir -p "$RUN_DIR"

cd "$LCB_DIR"

VENV_DIR="${LCB_VENV_DIR:-.venv-lite}"
if [[ ! -d "$VENV_DIR" ]]; then
  uv venv --python 3.11 "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

uv pip install --upgrade \
  "openai>=1.59.6" \
  "datasets==2.19.2" \
  "pebble>=5.0.7" \
  "tqdm>=4.66.2" \
  "numpy>=1.26,<2.0" \
  "attrs>=23.2.0" \
  >/dev/null

MODEL_REPR="$(
  python3 - <<'PY' "$MODEL_NAME"
import sys
from lcb_runner.lm_styles import LanguageModelStore

model_name = sys.argv[1]
model = LanguageModelStore.get(model_name)
print(model.model_repr if model else model_name)
PY
)"

EVAL_ALL_FILE="output/${MODEL_REPR}/Scenario.codegeneration_${N}_${TEMP}_eval_all.json"
OUTPUT_BASE="output/${MODEL_REPR}/Scenario.codegeneration_${N}_${TEMP}"

if [[ "${RESET_OUTPUT:-0}" == "1" ]]; then
  rm -f "${OUTPUT_BASE}.json" "${OUTPUT_BASE}_eval.json" "${OUTPUT_BASE}_eval_all.json"
fi

echo "Model: $MODEL_NAME"
echo "OpenAI base: $API_BASE"
echo "Release: $RELEASE_VERSION"
echo "n=$N temp=$TEMP top_p=$TOP_P max_tokens=$MAX_TOKENS openai_timeout=$OPENAI_TIMEOUT"

total_start=$SECONDS
WINDOW_EVAL_FILES=()
for idx in "${!WINDOWS[@]}"; do
  window="${WINDOWS[$idx]}"
  window_limit="${WINDOW_LIMITS[$idx]}"
  read -r START_DATE END_DATE <<<"$window"
  stamp="${START_DATE}_to_${END_DATE}"
  stamp="${stamp//[^A-Za-z0-9._-]/_}"

  echo ""
  echo "=== Generating + evaluating window $START_DATE .. $END_DATE (limit $window_limit) ==="
  # Reset per-window outputs to avoid cross-window generation reuse artifacts.
  rm -f "${OUTPUT_BASE}.json" "${OUTPUT_BASE}_eval.json" "${OUTPUT_BASE}_eval_all.json"
  step_start=$SECONDS
  LCB_PROBLEM_LIMIT="$window_limit" python -m lcb_runner.runner.main \
    --model "$MODEL_NAME" \
    --scenario codegeneration \
    --release_version "$RELEASE_VERSION" \
    --openai_timeout "$OPENAI_TIMEOUT" \
    --start_date "$START_DATE" \
    --end_date "$END_DATE" \
    --n "$N" \
    --temperature "$TEMP" \
    --top_p "$TOP_P" \
    --max_tokens "$MAX_TOKENS" \
    --evaluate \
    --num_process_evaluate "$NUM_PROCESS_EVALUATE" \
    | tee "$RUN_DIR/generate_${stamp}.log"
  step_elapsed=$((SECONDS - step_start))
  echo "Window runtime (s): $step_elapsed"

  if [[ ! -f "$EVAL_ALL_FILE" ]]; then
    echo "Expected eval file not found after window run: $EVAL_ALL_FILE"
    exit 1
  fi
  window_eval_file="$RUN_DIR/eval_all_${stamp}.json"
  cp "$EVAL_ALL_FILE" "$window_eval_file"
  WINDOW_EVAL_FILES+=("$window_eval_file")
done
total_elapsed=$((SECONDS - total_start))

echo ""
echo "=== Per-window scores (Reddit subset windows) ==="
for idx in "${!WINDOWS[@]}"; do
  window="${WINDOWS[$idx]}"
  read -r START_DATE END_DATE <<<"$window"
  stamp="${START_DATE}_to_${END_DATE}"
  stamp="${stamp//[^A-Za-z0-9._-]/_}"
  window_eval_file="${WINDOW_EVAL_FILES[$idx]}"
  python -m lcb_runner.evaluation.compute_scores \
    --eval_all_file "$window_eval_file" \
    --start_date "$START_DATE" \
    --end_date "$END_DATE" \
    | tee "$RUN_DIR/scores_${stamp}.txt"
done

echo ""
echo "=== Combined scores over union of three windows (36 + 44 + 12 = 92 target) ==="
python - "${WINDOW_EVAL_FILES[@]}" <<'PY' | tee "$RUN_DIR/scores_union_three_windows.txt"
import json
import sys
from datetime import datetime

eval_all_files = sys.argv[1:]
windows = [
    (datetime(2024, 1, 1), datetime(2024, 2, 29)),
    (datetime(2024, 5, 1), datetime(2024, 6, 30)),
    (datetime(2025, 4, 1), datetime(2025, 5, 31)),
]

rows = []
for eval_all_file in eval_all_files:
    with open(eval_all_file, "r") as f:
        rows.extend(json.load(f))

def in_windows(dt: datetime) -> bool:
    return any(start <= dt <= end for start, end in windows)

filtered = []
for row in rows:
    dt = datetime.fromisoformat(row["contest_date"])
    if in_windows(dt):
        filtered.append(row)

if not filtered:
    print("No rows matched the three-window subset.")
    sys.exit(0)

def mean_pass(rows):
    return sum(r["pass@1"] for r in rows) / len(rows) if rows else 0.0

easy = [r for r in filtered if r.get("difficulty") == "easy"]
medium = [r for r in filtered if r.get("difficulty") == "medium"]
hard = [r for r in filtered if r.get("difficulty") == "hard"]

print(f"subset_size={len(filtered)}")
print(f"overall_pass@1={mean_pass(filtered):.4f}")
print(f"easy_pass@1={mean_pass(easy):.4f} count={len(easy)}")
print(f"medium_pass@1={mean_pass(medium):.4f} count={len(medium)}")
print(f"hard_pass@1={mean_pass(hard):.4f} count={len(hard)}")
PY

echo ""
echo "Total subset runtime (s): $total_elapsed"
echo "Outputs written under: $RUN_DIR"
