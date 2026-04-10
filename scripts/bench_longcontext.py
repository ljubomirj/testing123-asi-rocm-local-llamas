#!/usr/bin/env python3
"""
Realistic Long-Context Benchmark for LLM Servers

Tests performance with prefilled context (40K-50K tokens) and large prompts (10K-15K tokens).
This provides realistic baseline for production scenarios.

Usage:
    python3 bench_longcontext.py --base http://192.168.1.251:8081
    python3 bench_longcontext.py --base http://192.168.1.251:8081 --prefill-tokens 40000 --prompt-tokens 10000,15000
"""

import argparse
import json
import time
import requests
from typing import Optional, Tuple


def generate_text(num_tokens: int, topic: str = "technology") -> str:
    """
    Generate coherent text of approximately num_tokens tokens.
    Uses repetitive but varied content to simulate realistic context.
    """
    # Rough estimate: 1 token ≈ 4 characters for English text
    chars_needed = num_tokens * 4

    templates = [
        "The evolution of {topic} has transformed modern society in unprecedented ways. ",
        "Researchers continue to explore new frontiers in {topic}, pushing boundaries daily. ",
        "Industry leaders emphasize the importance of {topic} for future innovation. ",
        "Academic institutions worldwide are investing heavily in {topic} education programs. ",
        "The practical applications of {topic} extend across multiple sectors and industries. ",
        "Experts predict that {topic} will revolutionize how we approach complex problems. ",
        "Historical analysis shows that {topic} has undergone several paradigm shifts. ",
        "Current debates surrounding {topic} focus on ethical implications and societal impact. ",
        "Emerging trends in {topic} suggest accelerating development in the coming decade. ",
        "Collaborative efforts in {topic} research have yielded remarkable breakthroughs recently. ",
    ]

    text = f"# Context Document: Overview of {topic.title()}\n\n"
    text += f"This document provides comprehensive background information about {topic}.\n\n"

    section = 1
    while len(text) < chars_needed:
        text += f"\n## Section {section}: Advanced Topics\n\n"
        for template in templates:
            text += template.format(topic=topic)
            if len(text) >= chars_needed:
                break
        section += 1

    return text[:chars_needed]


def create_prompt(num_tokens: int, task: str = "analysis") -> str:
    """Generate a prompt of approximately num_tokens tokens."""
    chars_needed = num_tokens * 4

    prompt = f"Based on the context provided above, please perform a detailed {task}. "
    prompt += "Consider the following aspects: "

    aspects = [
        "historical development and key milestones",
        "current state-of-the-art approaches and methodologies",
        "technical challenges and proposed solutions",
        "practical applications in various domains",
        "future research directions and open questions",
        "comparative analysis with alternative approaches",
        "scalability considerations and performance metrics",
        "integration strategies with existing systems",
        "cost-benefit analysis and resource requirements",
        "ethical implications and societal impact",
    ]

    while len(prompt) < chars_needed:
        for aspect in aspects:
            prompt += f"\n- {aspect.title()}: Provide comprehensive analysis with specific examples and evidence. "
            if len(prompt) >= chars_needed:
                break

    return prompt[:chars_needed]


def measure_request(
    url: str,
    model: str,
    system: str,
    user: str,
    max_tokens: int = 512,
    prefill_context: Optional[str] = None,
) -> Tuple[float, float, int, float, str]:
    """
    Measure TTFT, throughput, and total time for a request.

    Args:
        url: Base URL of the server
        model: Model name
        system: System prompt
        user: User prompt
        max_tokens: Maximum tokens to generate
        prefill_context: Optional context to send first to fill KV cache

    Returns:
        (ttft, chars_per_sec, response_chars, total_time, response_text)
    """
    endpoint = f"{url}/v1/chat/completions"

    # Step 1: Prefill context if provided
    if prefill_context:
        print(f"  Prefilling context ({len(prefill_context)} chars, ~{len(prefill_context)//4} tokens)...")
        prefill_start = time.time()

        prefill_payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": prefill_context}
            ],
            "max_tokens": 1,  # Just need to process context, not generate much
            "stream": False,
        }

        try:
            resp = requests.post(endpoint, json=prefill_payload, timeout=900)
            resp.raise_for_status()
            prefill_time = time.time() - prefill_start
            print(f"  Context prefilled in {prefill_time:.2f}s")
        except Exception as e:
            print(f"  Warning: Context prefill failed: {e}")
            # Continue anyway - server may have partial context

    # Step 2: Send actual prompt and measure
    print(f"  Sending prompt ({len(user)} chars, ~{len(user)//4} tokens)...")

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
        ],
        "max_tokens": max_tokens,
        "stream": True,
    }

    # Add prefill context again if provided (for servers that support context caching)
    if prefill_context:
        payload["messages"].append({"role": "user", "content": prefill_context})

    payload["messages"].append({"role": "user", "content": user})

    t0 = time.time()
    first_token_t = None
    response_text = ""
    n_chars = 0

    try:
        with requests.post(endpoint, json=payload, stream=True, timeout=1200) as resp:
            resp.raise_for_status()

            for line in resp.iter_lines():
                if not line:
                    continue

                line_str = line.decode('utf-8')
                if not line_str.startswith('data: '):
                    continue

                if line_str == 'data: [DONE]':
                    break

                try:
                    data = json.loads(line_str[6:])
                    if 'choices' in data and len(data['choices']) > 0:
                        delta = data['choices'][0].get('delta', {})
                        # GLM-4 models use reasoning_content, others use content
                        content = delta.get('content', '') or delta.get('reasoning_content', '')

                        if content:
                            if first_token_t is None:
                                first_token_t = time.time()
                            response_text += content
                            n_chars += len(content)
                except json.JSONDecodeError:
                    continue

        t1 = time.time()
        dt = t1 - t0

        ttft = (first_token_t - t0) if first_token_t else None
        chars_per_sec = (n_chars / dt) if dt > 0 else None

        return ttft, chars_per_sec, n_chars, dt, response_text

    except Exception as e:
        print(f"  ERROR: {e}")
        return None, None, 0, 0, ""


def main():
    parser = argparse.ArgumentParser(
        description="Realistic long-context benchmark for LLM servers"
    )
    parser.add_argument(
        "--base",
        default="http://localhost:8081",
        help="Base URL of the server (default: http://localhost:8081)",
    )
    parser.add_argument(
        "--model",
        default="default",
        help="Model name (default: default)",
    )
    parser.add_argument(
        "--prefill-tokens",
        type=int,
        default=40000,
        help="Number of tokens to prefill in context (default: 40000)",
    )
    parser.add_argument(
        "--prompt-tokens",
        default="10000,15000",
        help="Comma-separated list of prompt sizes in tokens (default: 10000,15000)",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=512,
        help="Maximum tokens to generate (default: 512)",
    )
    parser.add_argument(
        "--runs",
        type=int,
        default=3,
        help="Number of runs per test (default: 3)",
    )
    parser.add_argument(
        "--output",
        default="benchmark_longcontext_results.jsonl",
        help="Output JSONL file (default: benchmark_longcontext_results.jsonl)",
    )
    parser.add_argument(
        "--no-prefill",
        action="store_true",
        help="Skip context prefilling (compare with/without)",
    )

    args = parser.parse_args()

    prompt_sizes = [int(x.strip()) for x in args.prompt_tokens.split(",")]

    print("=" * 60)
    print("Long-Context Benchmark Configuration:")
    print("=" * 60)
    print(f"  Endpoint: {args.base}")
    print(f"  Model: {args.model}")
    if not args.no_prefill:
        print(f"  Context prefill: {args.prefill_tokens} tokens (~{args.prefill_tokens * 4} chars)")
    else:
        print(f"  Context prefill: DISABLED (empty context test)")
    print(f"  Prompt sizes: {prompt_sizes} tokens")
    print(f"  Runs per size: {args.runs}")
    print(f"  Max tokens: {args.max_tokens}")
    print(f"  Output: {args.output}")
    print()

    # Generate context once (reused across tests)
    context = None
    if not args.no_prefill:
        print("Generating context...")
        context = generate_text(args.prefill_tokens, topic="artificial intelligence")
        print(f"  Generated {len(context)} chars (~{len(context)//4} tokens)")
        print()

    system_prompt = "You are a helpful AI assistant with expertise in technology and research."

    results = []

    for prompt_tokens in prompt_sizes:
        print("=" * 60)
        print(f"Testing with {prompt_tokens} token prompts")
        if not args.no_prefill:
            print(f"  + {args.prefill_tokens} tokens of prefilled context")
            print(f"  = ~{args.prefill_tokens + prompt_tokens} total active context")
        print("=" * 60)
        print()

        for run in range(1, args.runs + 1):
            print(f"Run {run}/{args.runs}:")

            # Generate unique prompt for each run
            prompt = create_prompt(prompt_tokens, task=f"analysis run {run}")

            ttft, cps, n_chars, total_time, response = measure_request(
                url=args.base,
                model=args.model,
                system=system_prompt,
                user=prompt,
                max_tokens=args.max_tokens,
                prefill_context=context,
            )

            result = {
                "run_id": run,
                "prompt_tokens": prompt_tokens,
                "prefill_tokens": args.prefill_tokens if not args.no_prefill else 0,
                "total_context_tokens": (args.prefill_tokens if not args.no_prefill else 0) + prompt_tokens,
                "max_tokens": args.max_tokens,
                "ttft_sec": ttft,
                "chars_per_sec": cps,
                "tokens_per_sec": (cps / 4) if cps else None,  # Rough estimate
                "response_chars": n_chars,
                "response_tokens": n_chars // 4,  # Rough estimate
                "total_time_sec": total_time,
            }

            results.append(result)

            print(f"  TTFT: {ttft:.3f}s" if ttft else "  TTFT: N/A")
            print(f"  Throughput: {cps:.1f} chars/sec (~{cps/4:.1f} tok/s)" if cps else "  Throughput: N/A")
            print(f"  Total time: {total_time:.3f}s")
            print(f"  Generated: {n_chars} chars (~{n_chars//4} tokens)")
            print()

        # Calculate averages for this prompt size
        valid_results = [r for r in results if r["prompt_tokens"] == prompt_tokens and r["ttft_sec"] is not None]
        if valid_results:
            avg_ttft = sum(r["ttft_sec"] for r in valid_results) / len(valid_results)
            avg_throughput = sum(r["chars_per_sec"] for r in valid_results) / len(valid_results)
            avg_tok_s = avg_throughput / 4

            print(f"Average for {prompt_tokens} token prompts:")
            print(f"  TTFT: {avg_ttft:.3f}s")
            print(f"  Throughput: {avg_throughput:.1f} chars/s (~{avg_tok_s:.1f} tok/s)")
            print()

    # Save results
    print("=" * 60)
    print(f"Saving results to: {args.output}")
    with open(args.output, "w") as f:
        for result in results:
            f.write(json.dumps(result) + "\n")

    print(f"Total runs: {len(results)}")
    print()

    # Summary
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)

    for prompt_tokens in prompt_sizes:
        valid = [r for r in results if r["prompt_tokens"] == prompt_tokens and r["ttft_sec"]]
        if valid:
            avg_ttft = sum(r["ttft_sec"] for r in valid) / len(valid)
            avg_tps = sum(r["tokens_per_sec"] for r in valid) / len(valid)
            total_ctx = valid[0]["total_context_tokens"]

            print(f"  Prompt {prompt_tokens} tokens (total context ~{total_ctx} tokens):")
            print(f"    TTFT: {avg_ttft:.3f}s")
            print(f"    Throughput: {avg_tps:.1f} tok/s")

    print()
    print("Benchmark complete!")
    print()

    if not args.no_prefill:
        print("To compare with empty context, run:")
        print(f"  python3 {__file__} --base {args.base} --no-prefill")


if __name__ == "__main__":
    main()
