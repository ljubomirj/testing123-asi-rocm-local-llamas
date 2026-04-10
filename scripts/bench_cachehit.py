#!/usr/bin/env python3
"""
Cache-Hit Benchmark: Measures decode speed when KV cache is fully warm.

Sends the same prompt twice - first to warm the cache, second to measure
pure decode speed with near-zero prefill. Uses server-reported token counts
(not chars/4 estimation) for accurate tok/s measurement.

Also tests with streaming to measure TTFT on cache hit.
"""

import argparse
import json
import time
import requests


def make_messages(system, user):
    return [
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ]


def request_nonstreaming(url, messages, max_tokens):
    """Non-streaming request - returns server-reported token counts."""
    payload = {
        "model": "default",
        "messages": messages,
        "max_tokens": max_tokens,
        "stream": False,
    }
    t0 = time.time()
    resp = requests.post(f"{url}/v1/chat/completions", json=payload, timeout=120)
    resp.raise_for_status()
    dt = time.time() - t0
    data = resp.json()

    usage = data.get("usage", {})
    prompt_tokens = usage.get("prompt_tokens", 0)
    completion_tokens = usage.get("completion_tokens", 0)

    content = ""
    if data.get("choices"):
        msg = data["choices"][0].get("message", {})
        content = msg.get("content", "") or msg.get("reasoning_content", "") or ""

    return {
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "total_time_sec": dt,
        "tokens_per_sec": completion_tokens / dt if dt > 0 and completion_tokens > 0 else 0,
        "content_chars": len(content),
    }


def request_streaming(url, messages, max_tokens):
    """Streaming request - measures TTFT and per-token throughput."""
    payload = {
        "model": "default",
        "messages": messages,
        "max_tokens": max_tokens,
        "stream": True,
        "stream_options": {"include_usage": True},
    }
    t0 = time.time()
    first_token_t = None
    n_chars = 0
    prompt_tokens = 0
    completion_tokens = 0

    with requests.post(f"{url}/v1/chat/completions", json=payload, stream=True, timeout=120) as resp:
        resp.raise_for_status()
        for line in resp.iter_lines():
            if not line:
                continue
            line_str = line.decode("utf-8")
            if not line_str.startswith("data: "):
                continue
            if line_str == "data: [DONE]":
                break
            try:
                data = json.loads(line_str[6:])
                # Check for usage in final chunk
                if "usage" in data:
                    usage = data["usage"]
                    prompt_tokens = usage.get("prompt_tokens", prompt_tokens)
                    completion_tokens = usage.get("completion_tokens", completion_tokens)
                if "choices" in data and len(data["choices"]) > 0:
                    delta = data["choices"][0].get("delta", {})
                    content = delta.get("content", "") or delta.get("reasoning_content", "")
                    if content:
                        if first_token_t is None:
                            first_token_t = time.time()
                        n_chars += len(content)
            except json.JSONDecodeError:
                continue

    t1 = time.time()
    dt = t1 - t0
    ttft = (first_token_t - t0) if first_token_t else None
    decode_time = (t1 - first_token_t) if first_token_t else dt

    return {
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "ttft_sec": ttft,
        "total_time_sec": dt,
        "decode_time_sec": decode_time,
        "tokens_per_sec_total": completion_tokens / dt if dt > 0 and completion_tokens > 0 else 0,
        "tokens_per_sec_decode": completion_tokens / decode_time if decode_time > 0 and completion_tokens > 0 else 0,
        "content_chars": n_chars,
        "chars_per_token": n_chars / completion_tokens if completion_tokens > 0 else 0,
    }


def generate_context(n_tokens, topic="technology"):
    """Generate filler context of approximately n_tokens tokens."""
    chars_needed = n_tokens * 4
    templates = [
        f"The evolution of {topic} has transformed modern society in unprecedented ways. ",
        f"Researchers continue to explore new frontiers in {topic}, pushing boundaries daily. ",
        f"Industry leaders emphasize the importance of {topic} for future innovation. ",
        f"Academic institutions worldwide are investing heavily in {topic} education programs. ",
        f"The practical applications of {topic} extend across multiple sectors and industries. ",
    ]
    text = f"# Overview of {topic.title()}\n\n"
    section = 1
    while len(text) < chars_needed:
        text += f"\n## Section {section}\n\n"
        for t in templates:
            text += t
            if len(text) >= chars_needed:
                break
        section += 1
    return text[:chars_needed]


def main():
    parser = argparse.ArgumentParser(description="Cache-hit benchmark")
    parser.add_argument("--base", default="http://192.168.1.251:8081")
    parser.add_argument("--max-tokens", type=int, default=512)
    parser.add_argument("--runs", type=int, default=5, help="Warm runs to measure (default: 5)")
    parser.add_argument("--output", default="benchmark_cachehit_results.jsonl")
    args = parser.parse_args()

    # Test scenarios: (label, context_tokens, prompt)
    scenarios = [
        ("tiny_nocache", 0, "What is 2+2? Answer briefly."),
        ("short_nocache", 0, "Explain what a CPU cache is in one paragraph."),
        ("with_1k_context", 1000, "Summarize the above document in one sentence."),
        ("with_5k_context", 5000, "Summarize the above document in one sentence."),
        ("with_10k_context", 10000, "Summarize the above document in one sentence."),
    ]

    system = "You are a helpful assistant. Be concise."
    results = []

    print("=" * 70)
    print("Cache-Hit Benchmark: Measuring decode speed with warm KV cache")
    print("=" * 70)
    print(f"  Server: {args.base}")
    print(f"  Max tokens: {args.max_tokens}")
    print(f"  Warm runs: {args.runs}")
    print()

    for label, ctx_tokens, prompt in scenarios:
        print("=" * 70)
        print(f"Scenario: {label} (context: {ctx_tokens} tokens)")
        print("=" * 70)

        if ctx_tokens > 0:
            context = generate_context(ctx_tokens)
            user_msg = context + "\n\n" + prompt
        else:
            user_msg = prompt

        messages = make_messages(system, user_msg)

        # Cold run (warms the cache)
        print("\n  [COLD] Warming cache (non-streaming)...")
        cold = request_nonstreaming(args.base, messages, args.max_tokens)
        print(f"    Prompt tokens: {cold['prompt_tokens']}")
        print(f"    Completion tokens: {cold['completion_tokens']}")
        print(f"    Total time: {cold['total_time_sec']:.3f}s")
        print(f"    Throughput: {cold['tokens_per_sec']:.1f} tok/s (server-reported tokens)")

        # Warm runs (cache hit - streaming for TTFT measurement)
        print(f"\n  [WARM] Running {args.runs} cache-hit measurements (streaming)...")
        warm_results = []
        for i in range(1, args.runs + 1):
            r = request_streaming(args.base, messages, args.max_tokens)
            warm_results.append(r)
            print(f"    Run {i}: TTFT {r['ttft_sec']:.4f}s | "
                  f"{r['completion_tokens']} tokens in {r['decode_time_sec']:.3f}s | "
                  f"{r['tokens_per_sec_decode']:.1f} tok/s (decode) | "
                  f"{r['tokens_per_sec_total']:.1f} tok/s (total) | "
                  f"chars/tok: {r['chars_per_token']:.2f}")

        # Averages
        valid = [r for r in warm_results if r["ttft_sec"] is not None and r["completion_tokens"] > 0]
        if valid:
            avg_ttft = sum(r["ttft_sec"] for r in valid) / len(valid)
            avg_decode_tps = sum(r["tokens_per_sec_decode"] for r in valid) / len(valid)
            avg_total_tps = sum(r["tokens_per_sec_total"] for r in valid) / len(valid)
            avg_cpt = sum(r["chars_per_token"] for r in valid) / len(valid)
            max_decode_tps = max(r["tokens_per_sec_decode"] for r in valid)

            print(f"\n  WARM AVERAGES ({label}):")
            print(f"    TTFT:             {avg_ttft:.4f}s")
            print(f"    Decode tok/s:     {avg_decode_tps:.1f} (avg), {max_decode_tps:.1f} (peak)")
            print(f"    Total tok/s:      {avg_total_tps:.1f}")
            print(f"    Chars/token:      {avg_cpt:.2f}")
            print()

            result = {
                "scenario": label,
                "context_tokens": ctx_tokens,
                "cold_prompt_tokens": cold["prompt_tokens"],
                "cold_completion_tokens": cold["completion_tokens"],
                "cold_total_time": cold["total_time_sec"],
                "cold_tok_s": cold["tokens_per_sec"],
                "warm_avg_ttft": avg_ttft,
                "warm_avg_decode_tok_s": avg_decode_tps,
                "warm_avg_total_tok_s": avg_total_tps,
                "warm_peak_decode_tok_s": max_decode_tps,
                "warm_avg_chars_per_token": avg_cpt,
                "warm_runs": [
                    {
                        "ttft": r["ttft_sec"],
                        "completion_tokens": r["completion_tokens"],
                        "decode_time": r["decode_time_sec"],
                        "decode_tok_s": r["tokens_per_sec_decode"],
                        "total_tok_s": r["tokens_per_sec_total"],
                        "chars_per_token": r["chars_per_token"],
                    }
                    for r in valid
                ],
            }
            results.append(result)

    # Save
    with open(args.output, "w") as f:
        for r in results:
            f.write(json.dumps(r) + "\n")

    # Final summary
    print("=" * 70)
    print("SUMMARY: Cache-Hit Decode Speed (server-reported tokens)")
    print("=" * 70)
    print(f"{'Scenario':<20} {'TTFT':>8} {'Decode tok/s':>14} {'Peak tok/s':>12} {'Chars/tok':>10}")
    print("-" * 70)
    for r in results:
        print(f"{r['scenario']:<20} {r['warm_avg_ttft']:>7.4f}s {r['warm_avg_decode_tok_s']:>13.1f} "
              f"{r['warm_peak_decode_tok_s']:>11.1f} {r['warm_avg_chars_per_token']:>9.2f}")
    print()
    print(f"Results saved to: {args.output}")


if __name__ == "__main__":
    main()
