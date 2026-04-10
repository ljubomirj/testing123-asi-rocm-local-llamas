#!/usr/bin/env python3
"""
Comprehensive benchmark for SGLang server.
Tracks: throughput, latency (TTFT), cache hit rates, memory usage.
"""
import json
import time
import argparse
import requests
import subprocess
import re
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import Optional


@dataclass
class BenchmarkResult:
    """Single benchmark run result"""
    run_id: int
    prompt_length: int
    max_tokens: int
    ttft_sec: Optional[float]
    chars_per_sec: Optional[float]
    total_chars: int
    total_time_sec: float
    cache_hit_rate: Optional[float]
    gpu_vram_used_mb: Optional[float]
    gpu_vram_total_mb: Optional[float]
    cached_tokens: Optional[int]
    prompt_tokens: Optional[int]
    generation_tokens: Optional[int]


def get_gpu_memory():
    """Get GPU memory usage using rocm-smi"""
    try:
        result = subprocess.run(
            ["rocm-smi", "--showmeminfo", "vram", "--json"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            # Parse rocm-smi JSON output
            # Format varies, try common patterns
            for key, value in data.items():
                if isinstance(value, dict) and "VRAM Total Memory (B)" in value:
                    total_bytes = value.get("VRAM Total Memory (B)", 0)
                    used_bytes = value.get("VRAM Total Used Memory (B)", 0)
                    return used_bytes / 1024**2, total_bytes / 1024**2
        # Fallback: parse text output
        result = subprocess.run(
            ["rocm-smi", "--showmeminfo", "vram"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            # Try to parse output like "VRAM Total Used Memory (B): 12345"
            for line in result.stdout.split('\n'):
                if 'VRAM Total Used Memory' in line:
                    match = re.search(r'(\d+)', line)
                    if match:
                        used_mb = int(match.group(1)) / 1024**2
                        return used_mb, None
    except Exception as e:
        print(f"Warning: Could not get GPU memory: {e}")
    return None, None


def get_prometheus_metric(base_url: str, metric_name: str):
    """Query Prometheus /metrics endpoint for a specific metric"""
    try:
        response = requests.get(f"{base_url}/metrics", timeout=5)
        if response.status_code == 200:
            # Parse Prometheus text format
            for line in response.text.split('\n'):
                if line.startswith(metric_name):
                    # Format: metric_name{labels} value
                    parts = line.split()
                    if len(parts) >= 2:
                        try:
                            return float(parts[-1])
                        except ValueError:
                            continue
    except Exception as e:
        print(f"Warning: Could not query {metric_name}: {e}")
    return None


def stream_chat(url, model, system, user, max_tokens=32768, verbose=0):
    """Run streaming chat request and measure performance"""
    t0 = time.time()
    first_token_t = None
    n_chars = 0
    response_parts = []

    payload = {
        "model": model,
        "stream": True,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "max_tokens": max_tokens,
        "temperature": 0.0,
    }

    with requests.post(url, json=payload, stream=True, timeout=600) as r:
        r.raise_for_status()
        for line in r.iter_lines(decode_unicode=True):
            if not line:
                continue
            if line.startswith("data: "):
                line = line[len("data: "):]
            if line.strip() == "[DONE]":
                break

            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            # OpenAI-style streaming deltas
            delta = event["choices"][0].get("delta", {})
            chunks = []
            content = delta.get("content")
            if isinstance(content, str):
                chunks.append(content)
            reasoning = delta.get("reasoning_content") or delta.get("reasoning")
            if isinstance(reasoning, str):
                chunks.append(reasoning)

            chunk = "".join(chunks)
            if chunk:
                if first_token_t is None:
                    first_token_t = time.time()
                n_chars += len(chunk)
                if verbose:
                    response_parts.append(chunk)

    t1 = time.time()
    ttft = (first_token_t - t0) if first_token_t else None
    dt = t1 - t0
    cps = (n_chars / dt) if dt > 0 else None
    response_text = "".join(response_parts) if verbose else ""
    return ttft, cps, n_chars, dt, response_text


def extend_to_len(text, target_len):
    """Extend text to target length with filler"""
    if target_len is None or target_len <= 0:
        return text
    if len(text) >= target_len:
        return text[:target_len]
    filler = "\nLorem ipsum dolor sit amet, consectetur adipiscing elit. "
    out = text
    while len(out) < target_len:
        out += filler
    return out[:target_len]


def main():
    ap = argparse.ArgumentParser(description="Comprehensive SGLang benchmark")
    ap.add_argument("--base", default="http://192.168.1.251:8081")
    ap.add_argument("--model", default="glm-4.7-flash")
    ap.add_argument("--runs", type=int, default=3, help="Runs per prompt length")
    ap.add_argument("--max-tokens", type=int, default=2048)
    ap.add_argument(
        "--prompt-lengths",
        type=str,
        default="100,1000,5000,10000,20000",
        help="Comma-separated prompt lengths to test"
    )
    ap.add_argument("--output", default="benchmark_results.jsonl", help="Output file")
    ap.add_argument("-v", action="count", default=0, help="Verbosity level")
    args = ap.parse_args()

    base_url = args.base.rstrip("/")
    chat_url = base_url + "/v1/chat/completions"
    prompt_lengths = [int(x) for x in args.prompt_lengths.split(",")]

    system = """You are a concise assistant. Answer with only the final answer."""

    user_base = """Write one short sentence confirming you are alive.
Then write a second sentence for the fun of it.
And then write as many sentences next, as there are sentences in this prompt."""

    print(f"Benchmark Configuration:")
    print(f"  Endpoint: {base_url}")
    print(f"  Model: {args.model}")
    print(f"  Prompt lengths: {prompt_lengths}")
    print(f"  Runs per length: {args.runs}")
    print(f"  Max tokens: {args.max_tokens}")
    print(f"  Output: {args.output}")
    print()

    results = []

    for prompt_len in prompt_lengths:
        print(f"\n{'='*60}")
        print(f"Testing prompt length: {prompt_len} chars")
        print(f"{'='*60}")

        user_prompt = extend_to_len(user_base, prompt_len)

        for run in range(args.runs):
            print(f"\nRun {run+1}/{args.runs}:")

            # Get initial GPU memory
            vram_used_before, vram_total = get_gpu_memory()

            # Run benchmark
            ttft, cps, n_chars, dt, response_text = stream_chat(
                chat_url,
                args.model,
                system,
                user_prompt,
                max_tokens=args.max_tokens,
                verbose=args.v,
            )

            # Get final metrics
            vram_used_after, _ = get_gpu_memory()
            cache_hit_rate = get_prometheus_metric(base_url, "sglang:cache_hit_rate")
            cached_tokens = get_prometheus_metric(base_url, "sglang:cached_tokens_total")
            prompt_tokens = get_prometheus_metric(base_url, "sglang:prompt_tokens_total")
            gen_tokens = get_prometheus_metric(base_url, "sglang:generation_tokens_total")

            result = BenchmarkResult(
                run_id=run + 1,
                prompt_length=prompt_len,
                max_tokens=args.max_tokens,
                ttft_sec=ttft,
                chars_per_sec=cps,
                total_chars=n_chars,
                total_time_sec=dt,
                cache_hit_rate=cache_hit_rate,
                gpu_vram_used_mb=vram_used_after,
                gpu_vram_total_mb=vram_total,
                cached_tokens=int(cached_tokens) if cached_tokens else None,
                prompt_tokens=int(prompt_tokens) if prompt_tokens else None,
                generation_tokens=int(gen_tokens) if gen_tokens else None,
            )

            results.append(result)

            # Print results
            ttft_str = f"{ttft:.3f}s" if ttft else "N/A"
            cps_str = f"{cps:.1f}" if cps else "N/A"
            cache_str = f"{cache_hit_rate:.2%}" if cache_hit_rate else "N/A"
            vram_str = f"{vram_used_after:.0f}MB" if vram_used_after else "N/A"

            print(f"  TTFT: {ttft_str}")
            print(f"  Throughput: {cps_str} chars/sec")
            print(f"  Total time: {dt:.3f}s")
            print(f"  Cache hit rate: {cache_str}")
            print(f"  GPU VRAM: {vram_str}")

            if args.v:
                print(f"\n  Response ({n_chars} chars):")
                print(f"  {response_text[:200]}...")

    # Save results
    with open(args.output, 'w') as f:
        for result in results:
            f.write(json.dumps(asdict(result)) + '\n')

    print(f"\n{'='*60}")
    print(f"Results saved to: {args.output}")
    print(f"Total runs: {len(results)}")

    # Summary statistics
    if results:
        print(f"\nSummary:")
        for prompt_len in prompt_lengths:
            runs = [r for r in results if r.prompt_length == prompt_len]
            if runs:
                avg_ttft = sum(r.ttft_sec for r in runs if r.ttft_sec) / len([r for r in runs if r.ttft_sec])
                avg_cps = sum(r.chars_per_sec for r in runs if r.chars_per_sec) / len([r for r in runs if r.chars_per_sec])
                avg_cache = sum(r.cache_hit_rate for r in runs if r.cache_hit_rate) / len([r for r in runs if r.cache_hit_rate]) if any(r.cache_hit_rate for r in runs) else None

                print(f"  Prompt {prompt_len}chars: TTFT={avg_ttft:.3f}s, Throughput={avg_cps:.1f}chars/s, Cache={avg_cache:.2%}" if avg_cache else f"  Prompt {prompt_len}chars: TTFT={avg_ttft:.3f}s, Throughput={avg_cps:.1f}chars/s")


if __name__ == "__main__":
    main()
