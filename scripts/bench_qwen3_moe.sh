#!/bin/bash
# Benchmark Qwen3-Coder-Next-UD-Q5_K_XL with different MoE offloading strategies
# Model: 80B parameters (512 experts, 10 active per token)
# Hardware: AMD 7900 XTX (24GB VRAM) + 128GB RAM

BUILD="/data1/data/llama.cpp/build-gigul2-hip-rocwmma-new"
MODEL="$HOME/llama.cpp/models/UD-Q5_K_XL/Qwen3-Coder-Next-UD-Q5_K_XL-00001-of-00003.gguf"
RESULTS_DIR="$HOME/rocm-glm-4.7-flash/bench_qwen3_results"
mkdir -p "$RESULTS_DIR"

echo "=== Qwen3-Coder-Next MoE Offloading Benchmark ==="
echo "Date: $(date)"
echo "Model: 80B parameters (512 experts, 10 active per token)"
echo "GPU: AMD 7900 XTX (24GB VRAM)"
echo "RAM: 128GB"
echo ""

# Test different n-cpu-moe values (number of layers' experts to keep on CPU)
# Total layers: 48 (blocks 0-47)
# More n-cpu-moe = more CPU offload = less VRAM used = slower but fits in memory

# Strategy: Test from aggressive CPU offload to minimal
# 48 = all experts on CPU (slowest, but guaranteed to fit)
# 40 = only last 8 layers' experts on GPU
# 30 = only last 18 layers' experts on GPU
# 27 = Reddit sweet spot for RTX 5090 + 32GB VRAM
# 20 = only last 28 layers' experts on GPU (likely OOM on 24GB)
# 16 = only last 32 layers' experts on GPU (likely OOM)

TESTS=(
    "48:all"
    "40:mostly-cpu"
    "35:heavy-cpu"
    "30:balanced"
    "27:reddit-sweet"
    "24:gpu-leaning"
    "20:aggressive-gpu"
)

echo "Will test n-cpu-moe values:"
for TEST in "${TESTS[@]}"; do
    N="${TEST%%:*}"
    LABEL="${TEST##*:}"
    echo "  - $N ($LABEL)"
done
echo ""

for TEST in "${TESTS[@]}"; do
    N_CPU_MOE="${TEST%%:*}"
    LABEL="${TEST##*:}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    OUTFILE="$RESULTS_DIR/bench_ncpu_moe_${N_CPU_MOE}_${LABEL}_${TIMESTAMP}.log"

    echo "========================================="
    echo "Testing: --n-cpu-moe $N_CPU_MOE ($LABEL)"
    echo "Output: $OUTFILE"
    echo "========================================="

    # llama-bench parameters:
    # -m: model file (part 1 of 3 - auto-loads parts 2,3)
    # -t: threads (10 for dual Xeon)
    # -fa: flash attention on (rocWMMA)
    # --n-cpu-moe: number of layers' experts to keep on CPU
    # -p: prompt size (128 tokens for quick test)
    # -n: generation size (64 tokens)
    # -r: repetitions (3 for average)

    "$BUILD/bin/llama-bench" \
        -m "$MODEL" \
        -t 10 \
        -fa 1 \
        --n-cpu-moe $N_CPU_MOE \
        -p 128 \
        -n 64 \
        -r 3 \
        2>&1 | tee "$OUTFILE"

    # Extract key metrics
    TPS=$(grep "tg64" "$OUTFILE" | tail -1 | awk '{print $NF}')
    LOAD_TIME=$(grep "load time" "$OUTFILE" | tail -1 | awk '{print $4}')

    echo ""
    echo "Summary: n-cpu-moe=$N_CPU_MOE ($LABEL)"
    echo "  Throughput: $TPS tokens/sec"
    echo "  Load time: $LOAD_TIME ms"
    echo ""

    # Small delay to let GPU cool
    sleep 2
done

echo "=== Benchmark Complete ==="
echo "Results: $RESULTS_DIR"
echo ""
echo "Comparison:"
echo "----------------------------------------"
for TEST in "${TESTS[@]}"; do
    N_CPU_MOE="${TEST%%:*}"
    LABEL="${TEST##*:}"
    LATEST=$(ls -t "$RESULTS_DIR"/bench_ncpu_moe_${N_CPU_MOE}_${LABEL}_*.log 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        TPS=$(grep "tg64" "$LATEST" | tail -1 | awk '{print $NF}')
        LOAD=$(grep "load time" "$LATEST" | tail -1 | awk '{print $4}')
        printf "%-20s | %8s tok/s | %10s ms load\n" "$LABEL" "$TPS" "$LOAD"
    fi
done
echo "----------------------------------------"
