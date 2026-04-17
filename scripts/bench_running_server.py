#!/usr/bin/env python3
"""
llama-bench style testing against a running llama-server.
Tests various PP (prompt processing) and TG (text generation) sizes.
"""

import json
import time
import urllib.request
import urllib.error
import statistics
from typing import List, Tuple

# Standard llama-bench PP/TG sizes
PP_SIZES = [16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
TG_SIZES = [8, 16, 32, 64, 128, 256, 512, 1024]

BASE_URL = "http://127.0.0.1:8081/v1"
MODEL = "qwen3.6-35b-a3b"


def create_prompt_tokens(n_tokens: int) -> str:
    """Create a prompt of approximately n_tokens."""
    # Each token is roughly 4 characters
    chars_needed = n_tokens * 4
    base = "The quick brown fox jumps over the lazy dog. " * 10
    prompt = ""
    while len(prompt) < chars_needed:
        prompt += base
    return prompt[:chars_needed]


def count_tokens(text: str) -> int:
    """Rough token count (4 chars per token)."""
    return len(text) // 4


def make_request(
    prompt_tokens: int,
    max_tokens: int,
    stream: bool = False,
) -> Tuple[float, float, int, str]:
    """
    Make a request and return (ttft, total_time, tokens_generated, full_text).
    """
    url = f"{BASE_URL}/chat/completions"
    
    prompt = create_prompt_tokens(prompt_tokens)
    
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "stream": stream,
        "temperature": 0.0,
        "top_p": 1.0,
    }
    
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"}
    )
    
    start = time.time()
    try:
        resp = urllib.request.urlopen(req, timeout=600)
        body = json.loads(resp.read().decode())
        total_time = time.time() - start
        
        content = body.get("choices", [{}])[0].get("message", {}).get("content", "")
        tokens_generated = count_tokens(content)
        
        # Approximate TTFT from total time and generation speed
        # For non-streaming, we estimate TTFT as ~20% of total time
        ttft = total_time * 0.2
        
        return ttft, total_time, tokens_generated, content[:100]
    except Exception as e:
        return 0, 0, 0, str(e)


def test_pp_size(pp_size: int, tg_size: int, runs: int = 2) -> dict:
    """Test a specific PP/TG combination."""
    ttfts = []
    total_times = []
    tokens_generated = []
    
    print(f"  PP={pp_size:4d}, TG={tg_size:4d}: ", end="", flush=True)
    
    for run in range(runs):
        ttft, total, tokens, _ = make_request(pp_size, tg_size)
        if ttft > 0:
            ttfts.append(ttft)
            total_times.append(total)
            tokens_generated.append(tokens)
            print(".", end="", flush=True)
        time.sleep(0.5)
    
    if ttfts:
        avg_ttft = statistics.mean(ttfts)
        avg_total = statistics.mean(total_times)
        avg_tokens = statistics.mean(tokens_generated)
        pp_speed = pp_size / avg_ttft if avg_ttft > 0 else 0
        tg_speed = avg_tokens / (avg_total - avg_ttft) if (avg_total - avg_ttft) > 0 else 0
        
        print(f" TTFT={avg_ttft:6.2f}s, PP={pp_speed:6.1f} t/s, TG={tg_speed:6.1f} t/s")
        
        return {
            "pp_size": pp_size,
            "tg_size": tg_size,
            "ttft": avg_ttft,
            "pp_speed": pp_speed,
            "tg_speed": tg_speed,
            "total_time": avg_total,
            "runs": len(ttfts),
        }
    else:
        print(" FAILED")
        return None


def main():
    print("=" * 70)
    print("llama-bench style testing against running server")
    print(f"Server: {BASE_URL}")
    print(f"Model: {MODEL}")
    print("=" * 70)
    
    # First, verify server is responding
    try:
        resp = urllib.request.urlopen(f"{BASE_URL}/models", timeout=10)
        print(f"Server OK: {json.loads(resp.read())['data'][0]['id']}")
    except Exception as e:
        print(f"Server error: {e}")
        return
    
    print("\n" + "=" * 70)
    print("PP/TG Matrix (TTFT, PP speed, TG speed)")
    print("=" * 70)
    
    results = []
    
    # Test various PP/TG combinations
    test_cases = [
        # Small PP, various TG
        (64, 8), (64, 16), (64, 32), (64, 64), (64, 128),
        # Medium PP, various TG
        (256, 16), (256, 32), (256, 64), (256, 128), (256, 256),
        # Large PP, various TG
        (512, 32), (512, 64), (512, 128), (512, 256),
        (1024, 64), (1024, 128), (1024, 256), (1024, 512),
        (2048, 128), (2048, 256), (2048, 512), (2048, 1024),
        # Very large PP
        (4096, 256), (4096, 512),
    ]
    
    for pp_size, tg_size in test_cases:
        result = test_pp_size(pp_size, tg_size, runs=2)
        if result:
            results.append(result)
    
    print("\n" + "=" * 70)
    print("Summary Table")
    print("=" * 70)
    print(f"{'PP':>6} {'TG':>6} {'TTFT':>8} {'PP t/s':>10} {'TG t/s':>10}")
    print("-" * 50)
    
    for r in results:
        print(f"{r['pp_size']:6d} {r['tg_size']:6d} {r['ttft']:8.2f}s {r['pp_speed']:10.1f} {r['tg_speed']:10.1f}")
    
    # Save results
    with open("bench_results.json", "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"\nResults saved to: bench_results.json")


if __name__ == "__main__":
    main()
