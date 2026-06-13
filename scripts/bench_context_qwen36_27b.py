#!/usr/bin/env python3
"""CONTEXT benchmark for Qwen3.6-27B-IQ4_NL - thinking ON only."""

import time
import json
import statistics
import urllib.request
import os
from datetime import datetime

SERVER_URL = os.environ.get("OPENAI_BASE_URL", "http://127.0.0.1:8081/v1")
MODEL = os.environ.get("MODEL", "qwen3.6-27b")

# Test cases: (prefill_tokens, prompt_tokens, bucket_name, runs)
TESTS = [
    # None context - no prefill
    (0, 50, "none", 6),
    (0, 100, "none", 6),
    # Small context - 5K prefill
    (5000, 10, "small", 6),
    (5000, 15, "small", 6),
    # Mid context - 20K prefill
    (20000, 10, "mid", 3),
    (20000, 15, "mid", 3),
    # Long context - 40K prefill
    (40000, 10, "long", 3),
    (40000, 15, "long", 3),
    # LongLong context - 100K prefill
    (100000, 10, "longlong", 1),
    (100000, 15, "longlong", 1),
]

def generate_prompt(prefill_tokens, prompt_tokens):
    """Generate a prompt with the specified token counts."""
    # Prefill text (repeated to reach target)
    prefill = "The quick brown fox jumps over the lazy dog. " * (prefill_tokens // 10 + 1)

    # Actual prompt
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

def run_test(prefill, prompt_tokens, bucket, runs):
    """Run a single test case."""
    print(f"\n=== Bucket: {bucket}, Context: {prefill + prompt_tokens} (prefill={prefill}, prompt={prompt_tokens}, runs={runs}) ===")

    full_prompt = generate_prompt(prefill, prompt_tokens)
    messages = [{"role": "user", "content": full_prompt}]

    ttfts = []
    throughputs = []
    output_tokens = []
    good_runs = 0

    for i in range(runs):
        print(f"  Run {i+1}/{runs}...", end="", flush=True)
        start = time.time()

        try:
            result = chat_completion(messages, max_tokens=200)

            end = time.time()

            # Extract timing info
            if "usage" in result:
                ttft = end - start
                total_tok = result["usage"].get("total_tokens", 0)
                prompt_tok = result["usage"].get("prompt_tokens", 0)
                completion_tok = result["usage"].get("completion_tokens", 0)

                # Filter out failed runs (too few tokens)
                if completion_tok >= 10:
                    throughput = completion_tok / (end - start) if end > start else 0
                    ttfts.append(ttft)
                    throughputs.append(throughput)
                    output_tokens.append(completion_tok)
                    good_runs += 1
                    print(f" TTFT={ttft:.3f}s, tok/s={throughput:.1f}")
                else:
                    print(f" FAIL (only {completion_tok} tokens)")
            else:
                print(f" ERROR: {result}")
        except Exception as e:
            print(f" ERROR: {e}")

    if ttfts:
        return {
            "bucket": bucket,
            "prefill": prefill,
            "prompt": prompt_tokens,
            "total_context": prefill + prompt_tokens,
            "ttft": statistics.mean(ttfts),
            "throughput": statistics.mean(throughputs),
            "runs": runs,
            "good_runs": good_runs,
        }
    return None

def main():
    print(f"Qwen3.6-27B-IQ4_NL CONTEXT Benchmark - Thinking ON")
    print(f"Server: {SERVER_URL}")
    print(f"Model: {MODEL}")
    print(f"Started: {datetime.now()}")

    results = []

    for prefill, prompt_tokens, bucket, runs in TESTS:
        result = run_test(prefill, prompt_tokens, bucket, runs)
        if result:
            results.append(result)

    print("\n" + "="*80)
    print("RESULTS SUMMARY - Thinking ON")
    print("="*80)
    print(f"| {'Bucket':<12} | {'Context':>12} | {'TTFT':>8} | {'tok/s':>8} | {'Good/Total':>12} |")
    print(f"|{'-'*13}|{'-'*14}|{'-'*10}|{'-'*10}|{'-'*14}|")

    for r in results:
        ctx_str = f"{r['total_context']:,}"
        print(f"| {r['bucket']:<12} | {ctx_str:>12} | {r['ttft']:8.3f}s | {r['throughput']:8.1f} | {r['good_runs']:>3}/{r['runs']:<3} |")

    return results

if __name__ == "__main__":
    main()
