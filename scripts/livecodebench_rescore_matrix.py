#!/usr/bin/env python3
import json
from dataclasses import dataclass
from pathlib import Path

from lcb_runner.benchmarks import load_code_generation_dataset
from lcb_runner.evaluation import codegen_metrics, extract_instance_results
from lcb_runner.lm_styles import LanguageModelStore
from lcb_runner.utils.extraction_utils import extract_code


@dataclass
class Window:
    start: str
    end: str
    limit: int


WINDOWS = [
    Window("2024-01-01", "2024-02-29", 36),
    Window("2024-05-01", "2024-06-30", 44),
    Window("2025-04-01", "2025-05-31", 12),
]

MODELS = [
    "Qwen3.5-35B-A3B-IQ4",
    "Qwen3.5-27B-Q4",
    "Qwen3.5-9B-Q8",
]


def load_window_benchmark(release_version: str, window: Window):
    bench = load_code_generation_dataset(
        release_version, start_date=window.start, end_date=window.end
    )
    bench = sorted(bench, key=lambda x: x.question_id)
    return bench[: window.limit]


def eval_pass1(benchmark, generations, num_proc: int, timeout: int):
    eval_samples = [x.get_evaluation_sample() for x in benchmark]
    metrics, raw_results, _ = codegen_metrics(
        eval_samples,
        generations,
        num_process_evaluate=num_proc,
        timeout=timeout,
    )
    graded = extract_instance_results(raw_results)
    by_diff = {"easy": [], "medium": [], "hard": []}
    for problem, g in zip(benchmark, graded):
        diff = problem.difficulty
        if hasattr(diff, "value"):
            diff = diff.value
        diff = str(diff).lower()
        by_diff.setdefault(diff, []).append(1.0 if g[0] else 0.0)

    def mean(xs):
        return sum(xs) / len(xs) if xs else 0.0

    return {
        "pass@1": metrics["pass@1"],
        "easy_pass@1": mean(by_diff.get("easy", [])),
        "medium_pass@1": mean(by_diff.get("medium", [])),
        "hard_pass@1": mean(by_diff.get("hard", [])),
        "count": len(benchmark),
    }


def main():
    root = Path(__file__).resolve().parents[1]
    lcb_dir = root / "LiveCodeBench"
    output_dir = lcb_dir / "output"
    release_version = "release_v6"
    num_proc = 12
    timeout = 6
    temp = "0.0"

    all_windows = [load_window_benchmark(release_version, w) for w in WINDOWS]
    union_benchmark = [p for win in all_windows for p in win]

    summary = {}
    for model in MODELS:
        model_style = LanguageModelStore[model].model_style
        output_file = (
            output_dir / model / f"Scenario.codegeneration_1_{temp}.json"
        )
        with output_file.open() as f:
            rows = json.load(f)
        by_qid = {r["question_id"]: r for r in rows}

        model_summary = {"windows": []}
        union_generations = []
        nonempty_total = 0
        for win_idx, benchmark in enumerate(all_windows):
            generations = []
            for problem in benchmark:
                row = by_qid[problem.question_id]
                extracted = [extract_code(out, model_style) for out in row["output_list"]]
                generations.append(extracted)
                if extracted and extracted[0].strip():
                    nonempty_total += 1
                union_generations.append(extracted)

            metrics = eval_pass1(benchmark, generations, num_proc, timeout)
            metrics.update(
                {
                    "start": WINDOWS[win_idx].start,
                    "end": WINDOWS[win_idx].end,
                    "limit": WINDOWS[win_idx].limit,
                }
            )
            model_summary["windows"].append(metrics)

        model_summary["union"] = eval_pass1(
            union_benchmark, union_generations, num_proc, timeout
        )
        model_summary["nonempty_code_first_sample"] = nonempty_total
        model_summary["total_rows"] = len(union_benchmark)
        summary[model] = model_summary

    out_json = root / "benchmark_results_livecodebench_rescored.json"
    with out_json.open("w") as f:
        json.dump(summary, f, indent=2)
    print(out_json)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
