#!/usr/bin/env python3
"""CONTEXT benchmark with 50K cap (MLX Metal GPU crash workaround)."""

import time
import json
import statistics
import urllib.request
import os
from datetime import datetime

SERVER_URL = os.environ.get("OPENAI_BASE_URL", "http://127.0.0.1:8081/v1")
MODEL = os.environ.get("MODEL", "mlx-community/Qwen3.6-35B-A3B-4bit")

# Test cases: (prefill_tokens, prompt_tokens, total_context, runs)
# CAPPED AT 50K TO AVOID METAL GPU CRASH AT 100K
TESTS = [
    # None context - no prefill
    (0, 50, 50, 3),
    (0, 100, 100, 3),
    # Small context - 5K prefill
    (5000, 10, 5010, 3),
    (5000, 15, 5015, 3),
    # Mid context - 20K prefill
    (20000, 10, 20010, 1),
    (20000, 15, 20015, 1),
    # Long context - 40K prefill
    (40000, 10, 40010, 1),
    (40000, 15, 40015, 1),
    # Maximum context - 50K prefill (CAPPED - 100K crashes on MLX)
    (50000, 10, 50010, 1),
    (50000, 15, 50015, 1),
]

def generate_prompt(prefill_tokens, prompt_tokens):
    """Generate a prompt with the specified token counts."""
    prefill = "The quick brown fox jumps over the lazy dog. " * (prefill_tokens // 10 + 1)

    if prompt_tokens <= 100:
        prompts = [
            "What is 2+2?",
            "Tell me a joke.",
            "Hello, how are you?",
        ]
        prompt = prompts[prompt_tokens % len(prompts)]
    else:
        prompt = "Please explain quantum computing in detail. " * (prompt_tokens // 8 + 1)

    return prefill + prompt

def chat_completion(messages, max_tokens=200):
    """Call chat completions API."""
    data = json.dumps({
        "model": MODEL,
        "messages": messages,
        "max_tokens": max_tokens,
        "stream": False,
    }).encode("utf-8")

    req = urllib.request.Request(
        f"{SERVER_URL}/chat/completions",
        data=data,
        headers={"Content-Type": "application/json"},
    )

    with urllib.request.urlopen(req, timeout=600) as response:
        result = json.loads(response.read().decode("utf-8"))
    return result

def run_test(prefill, prompt_tokens, total_context, runs):
    """Run a single test case."""
    print(f"\n=== Context: {total_context} (prefill={prefill}, prompt={prompt_tokens}, runs={runs}) ===")

    full_prompt = generate_prompt(prefill, prompt_tokens)
    messages = [{"role": "user", "content": full_prompt}]

    ttfts = []
    throughputs = []
    output_tokens = []

    for i in range(runs):
        print(f"  Run {i+1}/{runs}...", end="", flush=True)
        start = time.time()

        result = chat_completion(messages, max_tokens=200)

        end = time.time()

        if "usage" in result:
            ttft = end - start
            total_tok = result["usage"].get("total_tokens", 0)
            prompt_tok = result["usage"].get("prompt_tokens", 0)
            completion_tok = result["usage"].get("completion_tokens", 0)

            throughput = completion_tok / (end - start) if end > start else 0

            ttfts.append(ttft)
            throughputs.append(throughput)
            output_tokens.append(completion_tok)

            print(f" TTFT={ttft:.3f}s, tok/s={throughput:.1f}")
        else:
            print(f" ERROR: {result}")

    if ttfts:
        return {
            "prefill": prefill,
            "prompt": prompt_tokens,
            "total_context": total_context,
            "ttft": statistics.mean(ttfts),
            "throughput": statistics.mean(throughputs),
            "runs": runs,
        }
    return None

def main():
    print(f"MLX Qwen3.6-35B-A3B-4bit CONTEXT Benchmark (50K CAP)")
    print(f"Server: {SERVER_URL}")
    print(f"Model: {MODEL}")
    print(f"Started: {datetime.now()}")
    print(f"NOTE: 100K context skipped due to MLX Metal GPU crash")

    results = []

    for prefill, prompt_tokens, total_context, runs in TESTS:
        result = run_test(prefill, prompt_tokens, total_context, runs)
        if result:
            results.append(result)

    print("\n" + "="*60)
    print("RESULTS SUMMARY")
    print("="*60)
    print(f"| Total Context | Prefill | Prompt | TTFT | Throughput | Runs |")
    print(f"|---|---:|---:|---:|---:|---:|")

    for r in results:
        print(f"| {r['total_context']:,} | {r['prefill']:,} | {r['prompt']:,} | {r['ttft']:.3f}s | {r['throughput']:.1f} tok/s | {r['runs']} |")

    print("\nNOTE: 50K is the practical max for MLX on M2 Max.")
    print("      Beyond 50K, performance drops significantly.")
    print("      At 100K, MLX crashes with Metal GPU error.")

    return results

if __name__ == "__main__":
    main()
