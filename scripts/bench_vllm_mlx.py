#!/usr/bin/env python3
"""
Benchmark script for vLLM-MLX server (OpenAI API format)
Measures TTFT and throughput across different context sizes.
"""

import argparse
import json
import statistics
import time
import urllib.request
from typing import Dict, List, Tuple

# Simple prompt text for padding
PROMPT_TEXT = "The quick brown fox jumps over the lazy dog. "


def make_request(url: str, messages: List[Dict], max_tokens: int = 100) -> Dict:
    """Make a request to vLLM-MLX server."""
    data = {
        "model": "default",
        "messages": messages,
        "max_tokens": max_tokens,
        "stream": False
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(data).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )

    with urllib.request.urlopen(req, timeout=600) as response:
        return json.loads(response.read().decode("utf-8"))


def generate_content(prefill_tokens: int, target_tokens: int) -> str:
    """Generate content with specified token count."""
    # Rough estimate: 4 chars per token
    prefill_chars = prefill_tokens * 4
    target_chars = target_tokens * 4

    prefill = (PROMPT_TEXT * ((prefill_chars // len(PROMPT_TEXT)) + 1))[:prefill_chars]
    target = (PROMPT_TEXT * ((target_chars // len(PROMPT_TEXT)) + 1))[:target_chars]

    return prefill, target


def run_benchmark(
    base_url: str,
    prefill_tokens: int,
    total_tokens: int,
    num_runs: int = 3
) -> Tuple[float, float]:
    """
    Run benchmark for a single context size.
    Returns: (avg_ttft, avg_throughput)
    """
    ttfts = []
    throughputs = []

    for run in range(num_runs):
        prefill, target = generate_content(prefill_tokens, total_tokens - prefill_tokens)

        messages = [
            {"role": "user", "content": f"Please repeat this exactly: {target}"}
        ]

        # If prefill, add system message with context
        if prefill_tokens > 0:
            messages.insert(0, {"role": "system", "content": f"Context: {prefill}"})

        start_time = time.time()

        try:
            response = make_request(base_url, messages, max_tokens=total_tokens)

            end_time = time.time()
            total_time = end_time - start_time

            # Extract token usage
            usage = response.get("usage", {})
            prompt_tokens = usage.get("prompt_tokens", 0)
            completion_tokens = usage.get("completion_tokens", 0)

            # TTFT is the total time for first token (simplified as total request time)
            ttft = total_time

            # Throughput = total tokens generated / total time
            if completion_tokens > 0:
                throughput = completion_tokens / total_time
            else:
                throughput = 0.0

            ttfts.append(ttft)
            throughputs.append(throughput)

            print(f"  Run {run + 1}/{num_runs}: TTFT={ttft:.2f}s, throughput={throughput:.1f} tok/s")

        except Exception as e:
            print(f"  Run {run + 1}/{num_runs}: ERROR - {e}")
            continue

    if ttfts:
        avg_ttft = statistics.mean(ttfts)
        avg_throughput = statistics.mean(throughputs)
        return avg_ttft, avg_throughput
    else:
        return 0.0, 0.0


def main():
    parser = argparse.ArgumentParser(description="Benchmark vLLM-MLX server")
    parser.add_argument("--url", default="http://localhost:8081/v1/chat/completions",
                        help="Server URL")
    parser.add_argument("--runs", type=int, default=3,
                        help="Number of runs per test")
    parser.add_argument("--skip-longlong", action="store_true",
                        help="Skip longlong (100K+ context) tests")

    args = parser.parse_args()

    print(f"Benchmarking: {args.url}")
    print(f"Runs per test: {args.runs}")
    print()

    # Benchmark tiers
    tiers = [
        ("None", 50, 0),
        ("None", 100, 0),
        ("Small", 15000, 5000),
        ("Small", 20000, 5000),
        ("Mid", 30000, 20000),
        ("Mid", 35000, 20000),
        ("Long", 50000, 40000),
        ("Long", 55000, 40000),
    ]

    if not args.skip_longlong:
        tiers.extend([
            ("Longlong", 110000, 100000),
            ("Longlong", 115000, 100000),
        ])

    results = []

    print("┌─────────────────┬─────────┬──────────┬──────────┐")
    print("│     Context     │ Prefill │  TTFT    │ Thruput  │")
    print("├─────────────────┼─────────┼──────────┼──────────┤")

    for tier_name, total_tokens, prefill_tokens in tiers:
        print(f"{tier_name} ({total_tokens:,}) ...")

        ttft, throughput = run_benchmark(
            args.url,
            prefill_tokens,
            total_tokens,
            args.runs
        )

        results.append((tier_name, total_tokens, prefill_tokens, ttft, throughput))

        tier_label = f"{tier_name} ({total_tokens/1000:.0f}K)" if total_tokens >= 1000 else tier_name
        prefill_label = f"{prefill_tokens/1000:.0f}K" if prefill_tokens >= 1000 else str(prefill_tokens)
        ttft_str = f"{ttft:.2f}s" if ttft > 0 else "N/A"
        throughput_str = f"{throughput:.1f} t/s" if throughput > 0 else "N/A"

        print(f"│ {tier_label:15s} │ {prefill_label:7s} │ {ttft_str:8s} │ {throughput_str:8s} │")

    print("└─────────────────┴─────────┴──────────┴──────────┘")

    # Save results
    timestamp = time.strftime("%Y%m%d")
    results_file = f"benchmark_vllm_mlx_iquest_8bit_{timestamp}.json"

    with open(results_file, "w") as f:
        json.dump({
            "model": "IQuest-Coder-V1-14B-Thinking-MLX-8bit",
            "url": args.url,
            "timestamp": timestamp,
            "results": [
                {
                    "tier": tier,
                    "total_tokens": total,
                    "prefill_tokens": prefill,
                    "ttft": ttft,
                    "throughput": tp
                }
                for tier, total, prefill, ttft, tp in results
            ]
        }, f, indent=2)

    print(f"\nResults saved to: {results_file}")


if __name__ == "__main__":
    main()
