#!/usr/bin/env python3
import argparse
import json
import time
from pathlib import Path

import torch
import sgl_kernel  # noqa: F401


def load_model_dims(config_path: Path):
    cfg = json.loads(config_path.read_text())
    qk_nope = cfg.get("qk_nope_head_dim")
    qk_rope = cfg.get("qk_rope_head_dim")
    v_head_dim = cfg.get("v_head_dim")
    if qk_nope is None or qk_rope is None or v_head_dim is None:
        return None
    return {
        "head_num": cfg.get("num_attention_heads"),
        "kv_head_num": cfg.get("num_key_value_heads", cfg.get("num_attention_heads")),
        "qk_head_dim": qk_nope + qk_rope,
        "v_head_dim": v_head_dim,
        "kv_group_size": cfg.get("quantization_config", {}).get("group_size", 128),
    }


def main():
    parser = argparse.ArgumentParser(description="Microbench int8 KV MLA decode kernel")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(
            "/home/ljubomir/sglang-rocm-glm-4.7-flash/"
            "models--QuantTrio--GLM-4.7-Flash-AWQ/snapshots/"
            "88e3d3d913c0d97c8f505cdc03433c48226bedc3/config.json"
        ),
        help="Model config.json path for default dims",
    )
    parser.add_argument("--batch", type=int, default=1)
    parser.add_argument("--heads", type=int, default=None)
    parser.add_argument("--kv-heads", type=int, default=None)
    parser.add_argument("--qk-head-dim", type=int, default=None)
    parser.add_argument("--v-head-dim", type=int, default=None)
    parser.add_argument("--kv-group-size", type=int, default=None)
    parser.add_argument("--seq-len", type=int, default=256)
    parser.add_argument("--max-tokens", type=int, default=32768)
    parser.add_argument("--dtype", choices=["fp16", "fp32"], default="fp16")
    parser.add_argument("--iters", type=int, default=200)
    parser.add_argument("--warmup", type=int, default=20)
    parser.add_argument("--logit-cap", type=float, default=0.0)
    parser.add_argument("--sm-scale", type=float, default=1.0)
    args = parser.parse_args()

    defaults = load_model_dims(args.config) or {}
    head_num = args.heads or defaults.get("head_num") or 16
    kv_head_num = args.kv_heads or defaults.get("kv_head_num") or head_num
    qk_head_dim = args.qk_head_dim or defaults.get("qk_head_dim") or 128
    v_head_dim = args.v_head_dim or defaults.get("v_head_dim") or qk_head_dim
    kv_group_size = args.kv_group_size or defaults.get("kv_group_size") or 128

    if qk_head_dim % kv_group_size != 0 or v_head_dim % kv_group_size != 0:
        raise SystemExit(
            f"kv_group_size={kv_group_size} must divide qk_head_dim={qk_head_dim} "
            f"and v_head_dim={v_head_dim}"
        )

    device = torch.device("cuda")
    dtype = torch.float16 if args.dtype == "fp16" else torch.float32

    q = torch.randn(args.batch, head_num, qk_head_dim, device=device, dtype=dtype)
    k_cache = torch.randint(
        -128,
        127,
        (args.max_tokens, kv_head_num, qk_head_dim),
        device=device,
        dtype=torch.int8,
    )
    v_cache = torch.randint(
        -128,
        127,
        (args.max_tokens, kv_head_num, v_head_dim),
        device=device,
        dtype=torch.int8,
    )
    k_scale = torch.rand(
        args.max_tokens,
        kv_head_num,
        qk_head_dim // kv_group_size,
        device=device,
        dtype=torch.float16,
    )
    v_scale = torch.rand(
        args.max_tokens,
        kv_head_num,
        v_head_dim // kv_group_size,
        device=device,
        dtype=torch.float16,
    )

    seq_len = min(args.seq_len, args.max_tokens)
    kv_indptr = torch.arange(
        0, (args.batch + 1) * seq_len, seq_len, device=device, dtype=torch.int32
    )
    kv_indices = torch.arange(
        0, args.batch * seq_len, device=device, dtype=torch.int32
    )
    kv_indices = (kv_indices % seq_len).contiguous()

    out = torch.empty(args.batch, head_num, v_head_dim, device=device, dtype=dtype)

    torch.ops.sgl_kernel.decode_attention_int8_kv_mla(
        q,
        k_cache,
        v_cache,
        k_scale,
        v_scale,
        kv_indptr,
        kv_indices,
        out,
        float(args.sm_scale),
        float(args.logit_cap),
        int(kv_group_size),
    )
    torch.cuda.synchronize()

    for _ in range(args.warmup):
        torch.ops.sgl_kernel.decode_attention_int8_kv_mla(
            q,
            k_cache,
            v_cache,
            k_scale,
            v_scale,
            kv_indptr,
            kv_indices,
            out,
            float(args.sm_scale),
            float(args.logit_cap),
            int(kv_group_size),
        )
    torch.cuda.synchronize()

    start = time.perf_counter()
    for _ in range(args.iters):
        torch.ops.sgl_kernel.decode_attention_int8_kv_mla(
            q,
            k_cache,
            v_cache,
            k_scale,
            v_scale,
            kv_indptr,
            kv_indices,
            out,
            float(args.sm_scale),
            float(args.logit_cap),
            int(kv_group_size),
        )
    torch.cuda.synchronize()
    dt = time.perf_counter() - start

    it_time = dt / args.iters
    tokens = args.batch * seq_len
    tok_s = tokens / it_time if it_time > 0 else 0.0
    print(
        f"batch={args.batch} heads={head_num} kv_heads={kv_head_num} "
        f"qk_dim={qk_head_dim} v_dim={v_head_dim} kv_group={kv_group_size} "
        f"seq_len={seq_len} dtype={args.dtype}"
    )
    print(f"iters={args.iters} avg_ms={it_time*1000:.3f} tok/s={tok_s:.2f}")


if __name__ == "__main__":
    main()
