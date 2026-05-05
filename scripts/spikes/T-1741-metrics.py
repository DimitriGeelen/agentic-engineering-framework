#!/usr/bin/env python3
"""T-1741 Spike D metrics: 4-way model comparison on T-1736 benchmark.

Compares hermes3 (T-1740 baseline) vs qwen3, qwen35, gemma4 — all under the
T-1740 revised prompt template. Renders docs/reports/T-1741-spike-d.md.
"""
import argparse
import json
import statistics
from collections import Counter, defaultdict
from pathlib import Path

import yaml


CLASSES = ("GO", "NO-GO", "DEFER")


def load_truth(path: Path) -> dict[str, str]:
    return {e["id"]: e["label"] for e in yaml.safe_load(path.read_text())}


def load_predictions(path: Path) -> dict[str, dict]:
    out: dict[str, dict] = {}
    if not path.exists():
        return out
    for line in path.open():
        r = json.loads(line)
        out[r["id"]] = r
    return out


def per_class_pr(confusion: dict) -> dict:
    out = {}
    for c in CLASSES:
        tp = confusion.get((c, c), 0)
        fp = sum(confusion.get((t, c), 0) for t in CLASSES if t != c)
        fn = sum(confusion.get((c, p), 0) for p in CLASSES if p != c)
        precision = tp / (tp + fp) if (tp + fp) else 0.0
        recall = tp / (tp + fn) if (tp + fn) else 0.0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
        out[c] = {"tp": tp, "fp": fp, "fn": fn, "p": precision, "r": recall, "f1": f1}
    return out


def render_confusion(confusion) -> str:
    h = "| truth ↓ / pred → | GO | NO-GO | DEFER |\n|---|---|---|---|\n"
    rows = []
    for t in CLASSES:
        cells = [str(confusion.get((t, p), 0)) for p in CLASSES]
        rows.append(f"| **{t}** | {cells[0]} | {cells[1]} | {cells[2]} |")
    return h + "\n".join(rows)


def compute(truth, pred):
    confusion = defaultdict(int)
    n_correct = n_eval = parse_fails = errors = 0
    latencies = []
    confidences_correct = []
    confidences_wrong = []
    disagreements = []
    for pid, t_label in truth.items():
        if pid not in pred:
            errors += 1
            continue
        r = pred[pid]
        v = r.get("verdict") or ""
        if not r.get("ok"):
            errors += 1
            continue
        if v not in CLASSES:
            parse_fails += 1
            continue
        confusion[(t_label, v)] += 1
        if v == t_label:
            n_correct += 1
            if r.get("confidence") is not None:
                confidences_correct.append(r["confidence"])
        else:
            disagreements.append((pid, t_label, v, r.get("rationale", "")))
            if r.get("confidence") is not None:
                confidences_wrong.append(r["confidence"])
        n_eval += 1
        if r.get("latency_ms"):
            latencies.append(r["latency_ms"])
    metrics = per_class_pr(confusion)
    macro_f1 = statistics.fmean(metrics[c]["f1"] for c in CLASSES)
    accuracy = n_correct / n_eval if n_eval else 0.0
    return {
        "confusion": dict(confusion),
        "metrics": metrics,
        "macro_f1": macro_f1,
        "accuracy": accuracy,
        "n_correct": n_correct,
        "n_eval": n_eval,
        "parse_fails": parse_fails,
        "errors": errors,
        "p50": statistics.median(latencies) if latencies else 0.0,
        "conf_gap": (
            (statistics.fmean(confidences_correct) if confidences_correct else 0)
            - (statistics.fmean(confidences_wrong) if confidences_wrong else 0)
        ),
        "disagreements": disagreements,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--labels", default=".context/spikes/T-1736-labels.yaml")
    ap.add_argument(
        "--results",
        nargs="+",
        default=[
            "hermes3:.context/spikes/T-1740-results.jsonl",
            "qwen3:.context/spikes/T-1741-qwen3-results.jsonl",
            "qwen35:.context/spikes/T-1741-qwen35-results.jsonl",
            "gemma4:.context/spikes/T-1741-gemma4-results.jsonl",
        ],
        help="model_label:path pairs",
    )
    ap.add_argument("--out", default="docs/reports/T-1741-spike-d.md")
    ap.add_argument("--prompts", default=".context/spikes/T-1736-sampled.jsonl")
    args = ap.parse_args()

    truth = load_truth(Path(args.labels))
    prompts = {json.loads(l)["id"]: json.loads(l) for l in Path(args.prompts).open()}
    truth_dist = Counter(truth.values())
    always_go = truth_dist.get("GO", 0) / len(truth) if truth else 0.0

    runs = []
    for spec in args.results:
        label, _, path = spec.partition(":")
        pred = load_predictions(Path(path))
        if pred:
            runs.append((label, path, compute(truth, pred)))
        else:
            runs.append((label, path, None))

    # Identify best by accuracy, then by macro_f1 as tiebreaker (only among completed)
    completed = [(lab, p, r) for lab, p, r in runs if r is not None]
    if completed:
        best = max(completed, key=lambda x: (x[2]["accuracy"], x[2]["macro_f1"]))
        best_label = best[0]
        best_metrics = best[2]
    else:
        best_label = "n/a"
        best_metrics = None

    threshold_acc = 0.80
    threshold_go_recall = 0.85
    threshold_defer_f1 = 0.50

    L = []
    L.append("# T-1741 Spike D — alternative model evaluation\n")
    L.append("Closes the prompt-triage rollout decision arc that T-1733 (Spike A) opened, T-1736")
    L.append("(Spike B) measured, and T-1740 (Spike C) revised. Spike D swaps only the underlying")
    L.append("ollama model — prompt template stays at T-1740 baseline. All four models run on the")
    L.append("identical 50-prompt benchmark from `.context/spikes/T-1736-sampled.jsonl`.\n")
    L.append(f"## Headline\n")
    L.append("| model | accuracy | GO recall | DEFER F1 | macro F1 | conf-gap | p50 ms | errors |")
    L.append("|---|---|---|---|---|---|---|---|")
    for label, path, r in runs:
        if r is None:
            L.append(f"| {label} | — | — | — | — | — | — | (no results file) |")
            continue
        L.append(
            f"| {label} | {r['accuracy']:.2%} | {r['metrics']['GO']['r']:.3f} | "
            f"{r['metrics']['DEFER']['f1']:.3f} | {r['macro_f1']:.3f} | "
            f"{r['conf_gap']:+.3f} | {r['p50']:.0f} | {r['errors']}+{r['parse_fails']}p |"
        )
    L.append("")
    L.append(f"- **Always-GO baseline:** {always_go:.2%} (any model below this is worse than null)")
    L.append(f"- **Pass thresholds:** accuracy ≥ {threshold_acc:.0%} AND GO recall ≥ {threshold_go_recall:.2f} AND DEFER F1 ≥ {threshold_defer_f1:.2f}")
    L.append(f"- **Best by accuracy:** **{best_label}**")
    L.append("")

    for label, path, r in runs:
        L.append(f"## {label}\n")
        if r is None:
            L.append(f"_No results file at `{path}`_\n")
            continue
        L.append(f"- accuracy: **{r['accuracy']:.2%}** ({r['n_correct']}/{r['n_eval']})")
        L.append(f"- macro F1: {r['macro_f1']:.3f}")
        L.append(f"- conf-gap: {r['conf_gap']:+.3f}  (>0 = more confident when right)")
        L.append(f"- latency p50: {r['p50']:.0f}ms · errors: {r['errors']} · parse-fails: {r['parse_fails']}")
        L.append(f"- threshold check: acc≥{threshold_acc:.0%} **{r['accuracy']>=threshold_acc}** · "
                 f"GO recall≥{threshold_go_recall:.2f} **{r['metrics']['GO']['r']>=threshold_go_recall}** · "
                 f"DEFER F1≥{threshold_defer_f1:.2f} **{r['metrics']['DEFER']['f1']>=threshold_defer_f1}**")
        L.append("")
        L.append(render_confusion(r["confusion"]))
        L.append("")
        L.append("| class | precision | recall | F1 |")
        L.append("|---|---|---|---|")
        for c in CLASSES:
            m = r["metrics"][c]
            L.append(f"| {c} | {m['p']:.3f} | {m['r']:.3f} | {m['f1']:.3f} |")
        L.append("")

    if best_metrics:
        L.append("## Verdict")
        all_pass = (
            best_metrics["accuracy"] >= threshold_acc
            and best_metrics["metrics"]["GO"]["r"] >= threshold_go_recall
            and best_metrics["metrics"]["DEFER"]["f1"] >= threshold_defer_f1
        )
        if all_pass:
            L.append(f"\n**GO** — {best_label} clears all thresholds. T-1737 unblocked.")
        else:
            L.append(f"\n**NO-GO** — best model ({best_label}) does not clear all thresholds.")
            failing = []
            if best_metrics["accuracy"] < threshold_acc:
                failing.append(f"accuracy {best_metrics['accuracy']:.2%} < {threshold_acc:.0%}")
            if best_metrics["metrics"]["GO"]["r"] < threshold_go_recall:
                failing.append(f"GO recall {best_metrics['metrics']['GO']['r']:.3f} < {threshold_go_recall}")
            if best_metrics["metrics"]["DEFER"]["f1"] < threshold_defer_f1:
                failing.append(f"DEFER F1 {best_metrics['metrics']['DEFER']['f1']:.3f} < {threshold_defer_f1}")
            L.append(f"\nFailing: {'; '.join(failing)}")
            L.append("\nT-1737 (Slice 2) remains BLOCKED. See task `## Recommendation`.")

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(L) + "\n")
    print(f"report → {out_path}")
    if best_metrics:
        print(f"best: {best_label} acc={best_metrics['accuracy']:.2%}")
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main())
