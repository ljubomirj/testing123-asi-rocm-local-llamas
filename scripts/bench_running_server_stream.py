#!/usr/bin/env python3
"""
llama-bench style testing with streaming for accurate TTFT and TG speed.
"""

import json
import time
import urllib.request
import statistics
from typing import Tuple

BASE_URL = "http://127.0.0.1:8081/v1"
MODEL = "qwen3.6-35b-a3b"

# Standard llama-bench sizes
PP_SIZES = [64, 128, 256, 512, 1024, 2048, 4096, 8192]
TG_SIZES = [32, 64, 128, 256, 512, 1024]


def create_prompt(n_tokens: int) -> str:
    """Create a prompt of ~n_tokens (4 chars per token)."""
    chars = "The quick brown fox jumps over the lazy dog. " * 10
    prompt = ""
    while len(prompt) < n_tokens * 4:
        prompt += chars
    return prompt[:n_tokens * 4]


def make_request_stream(
    prompt_tokens: int,
    max_tokens: int,
) -> Tuple[float, float, float, int]:
    """
    Make streaming request, return (ttft, total_time, gen_time, tokens_generated).
    """
    url = f"{BASE_URL}/chat/completions"
    
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": create_prompt(prompt_tokens)}],
        "max_tokens": max_tokens,
        "stream": True,
        "temperature": 0.0,
    }
    
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"}
    )
    
    start = time.time()
    first_token_time = None
    total_chars = 0
    
    try:
        resp = urllib.request.urlopen(req, timeout=600)
        
        for line in resp:
            line = line.decode().strip()
            if not line.startswith("data: ") or line == "data: [DONE]":
                continue
            
            try:
                chunk = json.loads(line[6:])
                delta = chunk.get("choices", [{}])[0].get("delta", {})
                content = delta.get("content", "")
                
                if content and first_token_time is None:
                    first_token_time = time.time()
                
                total_chars += len(content)
            except:
                pass
        
        total_time = time.time() - start
        ttft = (first_token_time - start) if first_token_time else total_time
        gen_time = total_time - ttft
        tokens_gen = total_chars // 4  # rough estimate
        
        return ttft, total_time, gen_time, tokens_gen
        
    except Exception as e:
        print(f"Error: {e}")
        return 0, 0, 0, 0


def test_combination(pp: int, tg: int, runs: int = 2) -> dict:
    """Test PP/TG combination."""
    print(f"  PP={pp:4d}, TG={tg:4d}: ", end="", flush=True)
    
    ttfts, pp_speeds, tg_speeds = [], [], []
    
    for _ in range(runs):
        ttft, total, gen_time, tokens = make_request_stream(pp, tg)
        if ttft > 0 and tokens > 0:
            ttfts.append(ttft)
            pp_speeds.append(pp / ttft if ttft > 0 else 0)
            tg_speeds.append(tokens / gen_time if gen_time > 0 else 0)
            print(".", end="", flush=True)
        time.sleep(0.3)
    
    if ttfts:
        avg_ttft = statistics.mean(ttfts)
        avg_pp = statistics.mean(pp_speeds)
        avg_tg = statistics.mean(tg_speeds)
        print(f" TTFT={avg_ttft:6.2f}s, PP={avg_pp:7.1f} t/s, TG={avg_tg:6.1f} t/s")
        return {"pp": pp, "tg": tg, "ttft": avg_ttft, "pp_speed": avg_pp, "tg_speed": avg_tg}
    print(" FAILED")
    return None


def main():
    print("=" * 70)
    print("llama-bench style testing (streaming) against running server")
    print(f"Model: {MODEL}")
    print("=" * 70)
    
    # Verify server
    try:
        urllib.request.urlopen(f"{BASE_URL}/models", timeout=5)
        print("Server OK\n")
    except:
        print("Server not responding")
        return
    
    results = []
    
    # Test matrix: focus on common combinations
    test_cases = [
        # Small PP
        (64, 32), (64, 64), (64, 128),
        # Medium PP
        (256, 64), (256, 128), (256, 256), (256, 512),
        (512, 64), (512, 128), (512, 256), (512, 512),
        # Large PP
        (1024, 128), (1024, 256), (1024, 512), (1024, 1024),
        (2048, 256), (2048, 512), (2048, 1024),
        (4096, 512), (4096, 1024),
        # Very large PP (stress test)
        (8192, 512), (8192, 1024),
    ]
    
    for pp, tg in test_cases:
        r = test_combination(pp, tg, runs=2)
        if r:
            results.append(r)
    
    print("\n" + "=" * 70)
    print("Summary Table")
    print("=" * 70)
    print(f"{'PP':>5} {'TG':>5} {'TTFT':>8} {'PP t/s':>10} {'TG t/s':>10}")
    print("-" * 45)
    for r in results:
        print(f"{r['pp']:5d} {r['tg']:5d} {r['ttft']:8.2f}s {r['pp_speed']:10.1f} {r['tg_speed']:10.1f}")
    
    # Save
    with open("bench_stream_results.json", "w") as f:
        json.dump(results, f, indent=2)
    print("\nResults: bench_stream_results.json")


if __name__ == "__main__":
    main()
