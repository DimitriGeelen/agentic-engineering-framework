#!/usr/bin/env python3
"""T-1736 Spike B metrics: confusion matrix + per-class precision/recall.

Joins ground-truth labels (.context/spikes/T-1736-labels.yaml) with
classifier results (.context/spikes/T-1736-results.jsonl) by id and renders
docs/reports/T-1736-spike-b.md.
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
    for line in path.open():
        r = json.loads(line)
        out[r["id"]] = r
    return out


def per_class_precision_recall(confusion: dict[tuple[str, str], int]) -> dict[str, dict]:
    """confusion[(truth, pred)] = count."""
    out: dict[str, dict] = {}
    for c in CLASSES:
        tp = confusion.get((c, c), 0)
        fp = sum(confusion.get((t, c), 0) for t in CLASSES if t != c)
        fn = sum(confusion.get((c, p), 0) for p in CLASSES if p != c)
        precision = tp / (tp + fp) if (tp + fp) else 0.0
        recall = tp / (tp + fn) if (tp + fn) else 0.0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
        out[c] = {"tp": tp, "fp": fp, "fn": fn, "p": precision, "r": recall, "f1": f1}
    return out


def render_confusion_md(confusion: dict[tuple[str, str], int]) -> str:
    header = "| truth ↓ / pred → | GO | NO-GO | DEFER |\n|---|---|---|---|\n"
    rows = []
    for t in CLASSES:
        cells = [str(confusion.get((t, p), 0)) for p in CLASSES]
        rows.append(f"| **{t}** | {cells[0]} | {cells[1]} | {cells[2]} |")
    return header + "\n".join(rows)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--labels", default=".context/spikes/T-1736-labels.yaml")
    ap.add_argument("--results", default=".context/spikes/T-1736-results.jsonl")
    ap.add_argument("--out", default="docs/reports/T-1736-spike-b.md")
    ap.add_argument("--prompts", default=".context/spikes/T-1736-sampled.jsonl")
    args = ap.parse_args()

    truth = load_truth(Path(args.labels))
    pred = load_predictions(Path(args.results))
    prompts = {json.loads(l)["id"]: json.loads(l) for l in Path(args.prompts).open()}

    # Build confusion matrix; track parse failures and errors separately
    confusion: dict[tuple[str, str], int] = defaultdict(int)
    parse_fails = []
    errors = []
    n_correct = 0
    n_eval = 0
    latencies = []
    confidences_correct = []
    confidences_wrong = []

    for pid, t_label in truth.items():
        if pid not in pred:
            errors.append((pid, "no-prediction"))
            continue
        r = pred[pid]
        verdict = r.get("verdict") or ""
        if not r.get("ok"):
            errors.append((pid, r.get("rationale", "?")))
            continue
        if verdict == "PARSE_FAIL":
            parse_fails.append(pid)
            continue
        if verdict not in CLASSES:
            parse_fails.append(pid)
            continue
        confusion[(t_label, verdict)] += 1
        if verdict == t_label:
            n_correct += 1
            if r.get("confidence") is not None:
                confidences_correct.append(r["confidence"])
        else:
            if r.get("confidence") is not None:
                confidences_wrong.append(r["confidence"])
        n_eval += 1
        if r.get("latency_ms"):
            latencies.append(r["latency_ms"])

    # Class distribution in ground truth
    truth_dist = Counter(truth.values())

    # Per-class metrics
    class_metrics = per_class_precision_recall(confusion)

    # Macro and weighted averages
    macro_p = statistics.fmean(class_metrics[c]["p"] for c in CLASSES)
    macro_r = statistics.fmean(class_metrics[c]["r"] for c in CLASSES)
    macro_f1 = statistics.fmean(class_metrics[c]["f1"] for c in CLASSES)
    n_true = {c: truth_dist.get(c, 0) for c in CLASSES}
    total = sum(n_true.values()) or 1
    weighted_f1 = sum(class_metrics[c]["f1"] * n_true[c] for c in CLASSES) / total

    # Naive baseline: always-GO accuracy
    always_go_acc = truth_dist.get("GO", 0) / len(truth) if truth else 0.0
    accuracy = n_correct / n_eval if n_eval else 0.0

    # Latency stats
    p50 = statistics.median(latencies) if latencies else 0.0
    p95 = sorted(latencies)[int(len(latencies) * 0.95)] if len(latencies) >= 20 else (max(latencies) if latencies else 0.0)
    mean_lat = statistics.fmean(latencies) if latencies else 0.0

    # Build report
    report = []
    report.append("# T-1736 Spike B — prompt-triage classifier accuracy\n")
    report.append("Sibling of T-1733 (Spike A: substrate). Spike A established that the substrate")
    report.append("works end-to-end (litellm:4000 → ollama hermes3:8b, p50 ~1s, $0). Spike B")
    report.append("measures classifier accuracy on real user prompts harvested from 30 days of")
    report.append("session JSONLs across all consumer projects.\n")
    report.append("## Methodology\n")
    report.append("- **Harvest:** `~/.claude/projects/*/*.jsonl`, last 30 days, deduplicated, filtered")
    report.append("  to plain-string user messages 40–2000 chars long, sub-agent prompts kept (they")
    report.append("  are agent-issued but pass through `type:user` and the classifier sees them in")
    report.append("  production too via UserPromptSubmit).")
    report.append("- **Sample:** 50 prompts, stratified roughly equally across consumer projects.")
    report.append("- **Labels:** Hand-labeled by the framework agent against the verdict definitions in")
    report.append("  `prompts/prompt-triage.md`. Single-rater (caveat: not blind).")
    report.append("- **Run:** `claude-3-5-sonnet-hermes3` via litellm:4000, temp=0, max_tokens=256.\n")
    report.append("## Class distribution (ground truth)\n")
    for c in CLASSES:
        n = truth_dist.get(c, 0)
        pct = 100.0 * n / len(truth) if truth else 0.0
        report.append(f"- **{c}:** {n} ({pct:.1f}%)")
    report.append("")
    report.append(f"## Headline numbers (n={n_eval})\n")
    report.append(f"- **Accuracy:** {accuracy:.2%} ({n_correct}/{n_eval})")
    report.append(f"- **Always-GO baseline:** {always_go_acc:.2%}  ← classifier must beat this to add value")
    report.append(f"- **Macro precision:** {macro_p:.3f}")
    report.append(f"- **Macro recall:** {macro_r:.3f}")
    report.append(f"- **Macro F1:** {macro_f1:.3f}")
    report.append(f"- **Weighted F1:** {weighted_f1:.3f}")
    report.append(f"- **Latency p50:** {p50:.0f}ms · p95: {p95:.0f}ms · mean: {mean_lat:.0f}ms")
    report.append(f"- **Parse failures:** {len(parse_fails)} / {len(truth)}")
    report.append(f"- **Errors:** {len(errors)} / {len(truth)}\n")
    report.append("## Confusion matrix\n")
    report.append(render_confusion_md(confusion))
    report.append("")
    report.append("## Per-class metrics\n")
    report.append("| class | TP | FP | FN | precision | recall | F1 |")
    report.append("|---|---|---|---|---|---|---|")
    for c in CLASSES:
        m = class_metrics[c]
        report.append(
            f"| {c} | {m['tp']} | {m['fp']} | {m['fn']} | {m['p']:.3f} | {m['r']:.3f} | {m['f1']:.3f} |"
        )
    report.append("")
    if confidences_correct or confidences_wrong:
        mean_correct = statistics.fmean(confidences_correct) if confidences_correct else 0
        mean_wrong = statistics.fmean(confidences_wrong) if confidences_wrong else 0
        report.append("## Confidence calibration\n")
        report.append(
            f"- **Mean confidence on correct:** {mean_correct:.3f} (n={len(confidences_correct)})"
        )
        report.append(
            f"- **Mean confidence on wrong:** {mean_wrong:.3f} (n={len(confidences_wrong)})"
        )
        gap = mean_correct - mean_wrong
        report.append(
            f"- **Gap:** {gap:+.3f} — positive means model is more confident when right."
        )
        report.append("")
    if parse_fails:
        report.append("## Parse failures\n")
        for pid in parse_fails[:10]:
            text = prompts.get(pid, {}).get("text", "?")[:120].replace("\n", " ")
            report.append(f"- `{pid}` — {text}")
        if len(parse_fails) > 10:
            report.append(f"- ...and {len(parse_fails) - 10} more")
        report.append("")
    if errors:
        report.append("## Errors\n")
        for pid, msg in errors[:5]:
            report.append(f"- `{pid}` — {msg}")
        report.append("")

    # Disagreements (truth vs pred mismatches), top 10
    report.append("## Sample disagreements\n")
    n_shown = 0
    for pid, t_label in truth.items():
        if n_shown >= 10:
            break
        if pid not in pred:
            continue
        r = pred[pid]
        v = r.get("verdict")
        if v in CLASSES and v != t_label:
            text = prompts.get(pid, {}).get("text", "?")[:140].replace("\n", " ")
            rat = r.get("rationale", "")[:120]
            report.append(f"- **truth: {t_label}, pred: {v}** (`{pid}`)")
            report.append(f"  - prompt: `{text}`")
            report.append(f"  - rationale: {rat}")
            n_shown += 1
    report.append("")
    report.append("## Recommendation context\n")
    report.append("See task `## Recommendation` block for the GO/NO-GO/DEFER call on production")
    report.append("rollout, citing the numbers above.")

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(report) + "\n")
    print(f"report → {out_path}")
    print(f"accuracy: {accuracy:.2%} (vs always-GO baseline {always_go_acc:.2%})")
    print(f"macro F1: {macro_f1:.3f}")
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main())
