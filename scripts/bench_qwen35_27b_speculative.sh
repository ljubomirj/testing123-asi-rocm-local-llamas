#!/bin/bash
# Run benchmarks for Qwen3.5-27B with speculative decoding (0.8B draft)
# Label: llama.cpp hip-rocwmma qwen35-27b-speculative
# Date: 2026-03-05

set -e

BASE_URL="http://192.168.1.251:8081"
MODEL="Qwen3.5-27B-UD-Q4_K_XL.gguf"
BUILD_LABEL="llama-cpp-hip-rocwmma-qwen35-27b-speculative"
DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="benchmark_results_${BUILD_LABEL}_${DATE}"
RUNS=3

mkdir -p "$OUTPUT_DIR"

echo "========================================="
echo "Running Benchmarks: $BUILD_LABEL"
echo "Model: $MODEL + Qwen3.5-0.8B draft"
echo "Date: $DATE"
echo "========================================="
echo ""

# 1. NONE-CONTEXT (no prefill, 50, 100 token prompts)
echo "1. NONE-CONTEXT Benchmark (50, 100 tokens, no prefill)"
python3 bench_longcontext.py \
    --base "$BASE_URL" \
    --model "$MODEL" \
    --no-prefill \
    --prompt-tokens "50,100" \
    --runs "$RUNS" \
    --output "${OUTPUT_DIR}/none_context_results.jsonl"

echo ""
echo "2. SMALL-CONTEXT Benchmark (5K prefill + 10K,15K prompts = 15K-20K total)"
python3 bench_longcontext.py \
    --base "$BASE_URL" \
    --model "$MODEL" \
    --prefill-tokens 5000 \
    --prompt-tokens "10000,15000" \
    --runs "$RUNS" \
    --output "${OUTPUT_DIR}/small_context_results.jsonl"

echo ""
echo "3. MID-CONTEXT Benchmark (20K prefill + 10K,15K prompts = 30K-35K total)"
python3 bench_longcontext.py \
    --base "$BASE_URL" \
    --model "$MODEL" \
    --prefill-tokens 20000 \
    --prompt-tokens "10000,15000" \
    --runs "$RUNS" \
    --output "${OUTPUT_DIR}/mid_context_results.jsonl"

echo ""
echo "4. LONG-CONTEXT Benchmark (40K prefill + 10K,15K prompts = 50K-55K total)"
python3 bench_longcontext.py \
    --base "$BASE_URL" \
    --model "$MODEL" \
    --prefill-tokens 40000 \
    --prompt-tokens "10000,15000" \
    --runs "$RUNS" \
    --output "${OUTPUT_DIR}/long_context_results.jsonl"

echo ""
echo "5. LONGLONG-CONTEXT Benchmark (100K prefill + 10K,15K prompts = 110K-115K total)"
python3 bench_longcontext.py \
    --base "$BASE_URL" \
    --model "$MODEL" \
    --prefill-tokens 100000 \
    --prompt-tokens "10000,15000" \
    --runs "$RUNS" \
    --output "${OUTPUT_DIR}/longlong_context_results.jsonl"

echo ""
echo "========================================="
echo "All benchmarks complete!"
echo "Results saved to: $OUTPUT_DIR/"
echo "========================================="

# Generate summary table
echo ""
echo "========================================="
echo "RESULTS SUMMARY TABLE"
echo "========================================="
printf "%-16s | %8s | %9s | %9s\n" "Context" "Prefill" "TTFT (s)" "Thruput (t/s)"
echo "------------------+----------+-----------+----------"

for context in none small mid long longlong; do
    case $context in
        none)
            label="None (50 tok)"; prefill="0"
            ;;
        small)
            label="Small (15K)"; prefill="5K"
            ;;
        mid)
            label="Mid (30K)"; prefill="20K"
            ;;
        long)
            label="Long (50K)"; prefill="40K"
            ;;
        longlong)
            label="Longlong (110K)"; prefill="100K"
            ;;
    esac

    file="${OUTPUT_DIR}/${context}_context_results.jsonl"
    if [[ -f "$file" ]]; then
        # Get averages for first prompt size (50 for none, 10000 for others)
        if [[ "$context" == "none" ]]; then
            prompt_size="50"
        else
            prompt_size="10000"
        fi

        ttft=$(jq -r "select(.prompt_tokens == $prompt_size) | .ttft_sec" "$file" | awk '$1 != "null" {sum+=$1; count++} END {print sum/count}')
        tps=$(jq -r "select(.prompt_tokens == $prompt_size) | .tokens_per_sec" "$file" | awk '$1 != "null" {sum+=$1; count++} END {print sum/count}')

        printf "%-16s | %8s | %9.3f | %9.1f\n" "$label" "$prefill" "$ttft" "$tps"
    fi
done

echo "------------------+----------+-----------+----------"
echo ""
