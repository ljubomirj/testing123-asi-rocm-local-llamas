#!/usr/bin/env python3
"""LLama-bench style test for OpenAI-compatible server."""

import time
import json
import urllib.request
import os
from datetime import datetime

SERVER_URL = os.environ.get("OPENAI_BASE_URL", "http://127.0.0.1:8081/v1")
MODEL = os.environ.get("MODEL", "mlx-community/Qwen3.6-35B-A3B-4bit")

# Test cases: (pp, tg, runs) - pp = prompt tokens, tg = target (generation) tokens
TESTS = [
    (256, 512, 2),
    (512, 512, 2),
    (1024, 512, 2),
    (1024, 1024, 2),
    (2048, 512, 2),
    (2048, 1024, 2),
    (4096, 512, 1),
    (4096, 1024, 1),
    (8192, 512, 1),
]

PROMPT_TEMPLATE = "The following is a detailed technical explanation. "

def generate_prompt_tokens(n):
    """Generate a prompt with approximately n tokens."""
    base = PROMPT_TEMPLATE
    repeats = (n // len(base.split())) + 1
    return " ".join([base] * repeats)

def chat_completion(prompt, max_tokens):
    """Call chat completions API."""
    data = json.dumps({
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "stream": False,
    }).encode("utf-8")

    req = urllib.request.Request(
        f"{SERVER_URL}/chat/completions",
        data=data,
        headers={"Content-Type": "application/json"},
    )

    start = time.time()
    with urllib.request.urlopen(req, timeout=600) as response:
        result = json.loads(response.read().decode("utf-8"))
    end = time.time()

    return result, end - start

def run_test(pp, tg, runs):
    """Run a single test case."""
    print(f"\n=== PP={pp}, TG={tg}, runs={runs} ===")

    prompt = generate_prompt_tokens(pp)

    ttfts = []
    pp_speeds = []
    tg_speeds = []

    for i in range(runs):
        print(f"  Run {i+1}/{runs}...", end="", flush=True)
        result, elapsed = chat_completion(prompt, tg)

        if "usage" in result:
            ttft = elapsed
            prompt_tok = result["usage"].get("prompt_tokens", pp)
            completion_tok = result["usage"].get("completion_tokens", 0)

            pp_speed = pp / ttft if ttft > 0 else 0
            tg_speed = completion_tok / elapsed

            ttfts.append(ttft)
            pp_speeds.append(pp_speed)
            tg_speeds.append(tg_speed)

            print(f" TTFT={ttft:.2f}s, PP={pp_speed:.1f} t/s, TG={tg_speed:.1f} t/s")

    return {
        "pp": pp,
        "tg": tg,
        "ttft": sum(ttfts) / len(ttfts),
        "pp_speed": sum(pp_speeds) / len(pp_speeds),
        "tg_speed": sum(tg_speeds) / len(tg_speeds),
    }

def main():
    print(f"MLX Qwen3.6-35B-A3B-4bit LLAMA-BENCH Style Test")
    print(f"Server: {SERVER_URL}")
    print(f"Model: {MODEL}")
    print(f"Started: {datetime.now()}")

    results = []

    for pp, tg, runs in TESTS:
        result = run_test(pp, tg, runs)
        results.append(result)

    print("\n" + "="*70)
    print("RESULTS SUMMARY")
    print("="*70)
    print(f"| PP   | TG   | TTFT   | PP t/s | TG t/s |")
    print(f"|-----|-----|--------|--------|--------|")

    for r in results:
        print(f"| {r['pp']:4} | {r['tg']:4} | {r['ttft']:6.2f}s | {r['pp_speed']:6.1f} | {r['tg_speed']:6.1f} |")

    return results

if __name__ == "__main__":
    main()
