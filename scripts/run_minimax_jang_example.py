#!/usr/bin/env python3
from __future__ import annotations

import argparse
import time
from pathlib import Path

import mlx.core as mx
from jang_tools.loader import load_jang_model
from mlx_lm.generate import generate_step
from mlx_lm.sample_utils import make_sampler


DEFAULT_MODEL_PATH = Path(
    "/Users/ljubomir/.cache/huggingface/hub/"
    "models--JANGQ-AI--MiniMax-M2.5-JANG_2L/snapshots/"
    "6a2d1e1c9475a63961cfb17253436dbe5fd6fa65"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the local JANG MiniMax example and report timing.")
    parser.add_argument("--model-path", type=Path, default=DEFAULT_MODEL_PATH)
    parser.add_argument("--prompt", default="What is photosynthesis?")
    parser.add_argument("--max-tokens", type=int, default=6)
    parser.add_argument("--temp", type=float, default=1.0)
    parser.add_argument("--top-p", type=float, default=0.95)
    parser.add_argument("--top-k", type=int, default=40)
    parser.add_argument(
        "--repeat",
        type=int,
        default=1,
        help="Run generation multiple times after one load to separate cold and warm prompt timing.",
    )
    return parser.parse_args()


def run_once(model, tokenizer, sampler, prompt: str, max_tokens: int, label: str) -> None:
    tokens = tokenizer.encode(prompt)
    start = time.perf_counter()
    first_token_seconds = None
    generated: list[int] = []
    text_parts: list[str] = []

    for tok, _ in generate_step(prompt=mx.array(tokens), model=model, max_tokens=max_tokens, sampler=sampler):
        now = time.perf_counter()
        if first_token_seconds is None:
            first_token_seconds = now - start

        token_id = tok.item() if hasattr(tok, "item") else int(tok)
        generated.append(token_id)
        text_parts.append(tokenizer.decode([token_id]))
        if token_id == tokenizer.eos_token_id:
            break

    total_seconds = time.perf_counter() - start
    non_eos_tokens = len(generated) - (1 if generated and generated[-1] == tokenizer.eos_token_id else 0)
    decode_tokens = max(non_eos_tokens - 1, 0)
    decode_seconds = max(total_seconds - (first_token_seconds or 0.0), 0.0)
    decode_toks_per_s = (decode_tokens / decode_seconds) if decode_tokens and decode_seconds else 0.0

    print(
        f"{label}: prompt_tokens={len(tokens)} first_token_seconds={first_token_seconds:.2f} "
        f"generation_seconds={total_seconds:.2f} non_eos_tokens={non_eos_tokens} "
        f"decode_toks_per_s={decode_toks_per_s:.2f}"
    )
    print(f"{label}: text={''.join(text_parts)!r}")


def main() -> None:
    args = parse_args()
    if not args.model_path.exists():
        raise FileNotFoundError(f"Model path not found: {args.model_path}")

    print(f"model_path={args.model_path}")
    print(
        "sampler_settings="
        f"temp={args.temp} top_p={args.top_p} top_k={args.top_k} max_tokens={args.max_tokens}"
    )

    load_start = time.perf_counter()
    model, tokenizer = load_jang_model(args.model_path)
    load_seconds = time.perf_counter() - load_start
    print(f"load_seconds={load_seconds:.2f}")
    print(f"eos_token_id={tokenizer.eos_token_id}")

    sampler = make_sampler(temp=args.temp, top_p=args.top_p, top_k=args.top_k)

    for idx in range(args.repeat):
        run_once(model, tokenizer, sampler, args.prompt, args.max_tokens, f"run{idx + 1}")


if __name__ == "__main__":
    main()
