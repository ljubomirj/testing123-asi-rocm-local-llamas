#!/bin/bash
# Run all context benchmarks on the new llama.cpp hip-rocwmma-new build
# Label: llama.cpp hip-rocwmma-new linux glm-4.7-flash

set -e

BASE_URL="http://192.168.1.251:8081"
MODEL="GLM-4.7-Flash-UD-Q4_K_XL.gguf"
BUILD_LABEL="llama-cpp-hip-rocwmma-new"
DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="benchmark_results_${BUILD_LABEL}_${DATE}"
RUNS=3

mkdir -p "$OUTPUT_DIR"

echo "========================================="
echo "Running Benchmarks: $BUILD_LABEL"
echo "Model: $MODEL"
echo "Date: $DATE"
echo "========================================="
echo ""

# 1. NONE-CONTEXT (no prefill, tiny prompts)
echo "1. NONE-CONTEXT Benchmark (25, 50, 100 tokens, no prefill)"
python3 bench_longcontext.py \
    --base "$BASE_URL" \
    --model "$MODEL" \
    --no-prefill \
    --prompt-tokens "25,50,100" \
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
