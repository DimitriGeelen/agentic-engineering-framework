#!/usr/bin/env python3
"""T-1740 Spike C metrics: same as T-1736 but emits side-by-side delta vs baseline.

Renders docs/reports/T-1740-spike-c.md with full confusion matrix + per-class
metrics + a delta block comparing to T-1736 baseline (40% accuracy).
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


def per_class_pr(confusion: dict[tuple[str, str], int]) -> dict[str, dict]:
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


def render_confusion(confusion: dict[tuple[str, str], int]) -> str:
    header = "| truth ↓ / pred → | GO | NO-GO | DEFER |\n|---|---|---|---|\n"
    rows = []
    for t in CLASSES:
        cells = [str(confusion.get((t, p), 0)) for p in CLASSES]
        rows.append(f"| **{t}** | {cells[0]} | {cells[1]} | {cells[2]} |")
    return header + "\n".join(rows)


def compute(truth: dict, pred: dict) -> dict:
    confusion: dict[tuple[str, str], int] = defaultdict(int)
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
    macro_p = statistics.fmean(metrics[c]["p"] for c in CLASSES)
    macro_r = statistics.fmean(metrics[c]["r"] for c in CLASSES)
    macro_f1 = statistics.fmean(metrics[c]["f1"] for c in CLASSES)
    accuracy = n_correct / n_eval if n_eval else 0.0
    p50 = statistics.median(latencies) if latencies else 0.0
    return {
        "confusion": dict(confusion),
        "metrics": metrics,
        "macro_p": macro_p,
        "macro_r": macro_r,
        "macro_f1": macro_f1,
        "accuracy": accuracy,
        "n_correct": n_correct,
        "n_eval": n_eval,
        "parse_fails": parse_fails,
        "errors": errors,
        "p50": p50,
        "conf_correct": statistics.fmean(confidences_correct) if confidences_correct else 0.0,
        "conf_wrong": statistics.fmean(confidences_wrong) if confidences_wrong else 0.0,
        "disagreements": disagreements,
    }


def fmt_delta(new: float, old: float, pct: bool = False, plus_is_good: bool = True) -> str:
    delta = new - old
    if pct:
        sym = "+" if delta >= 0 else ""
        arrow = "↑" if (delta > 0) == plus_is_good else "↓" if delta != 0 else "="
        return f"{new:.2%} ({sym}{delta:+.2%} {arrow} vs {old:.2%})"
    sym = "+" if delta >= 0 else ""
    arrow = "↑" if (delta > 0) == plus_is_good else "↓" if delta != 0 else "="
    return f"{new:.3f} ({sym}{delta:+.3f} {arrow} vs {old:.3f})"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--labels", default=".context/spikes/T-1736-labels.yaml")
    ap.add_argument("--results-new", default=".context/spikes/T-1740-results.jsonl")
    ap.add_argument("--results-baseline", default=".context/spikes/T-1736-results.jsonl")
    ap.add_argument("--out", default="docs/reports/T-1740-spike-c.md")
    ap.add_argument("--prompts", default=".context/spikes/T-1736-sampled.jsonl")
    args = ap.parse_args()

    truth = load_truth(Path(args.labels))
    pred_new = load_predictions(Path(args.results_new))
    pred_baseline = load_predictions(Path(args.results_baseline))
    prompts = {json.loads(l)["id"]: json.loads(l) for l in Path(args.prompts).open()}

    new = compute(truth, pred_new)
    base = compute(truth, pred_baseline)

    truth_dist = Counter(truth.values())
    always_go = truth_dist.get("GO", 0) / len(truth) if truth else 0.0

    threshold_acc = 0.80
    threshold_go_recall = 0.85
    pass_acc = new["accuracy"] >= threshold_acc
    pass_go_recall = new["metrics"]["GO"]["r"] >= threshold_go_recall
    if pass_acc and pass_go_recall:
        verdict = "GO — T-1737 unblocked"
    elif pass_acc or pass_go_recall:
        verdict = "DEFER — partial pass; see Recommendation"
    else:
        verdict = "NO-GO — escalate to T-1741 (model switch)"

    # Build report
    L = []
    L.append("# T-1740 Spike C — revised prompt template, re-run on T-1736 benchmark\n")
    L.append("Sibling of T-1736 (Spike B). Spike B revealed a calibration gap — classifier under-")
    L.append("predicts GO on direct commands. Spike C revises `prompts/prompt-triage.md` to add")
    L.append("calibration examples for direct-command-GO patterns and re-runs the same 50-prompt")
    L.append("benchmark with no other change.\n")
    L.append("## Headline\n")
    L.append(f"- **Verdict:** {verdict}")
    L.append(f"- **Accuracy:** {fmt_delta(new['accuracy'], base['accuracy'], pct=True)}")
    L.append(f"- **Always-GO baseline:** {always_go:.2%} (must beat this to add value)")
    L.append(
        f"- **Macro F1:** {fmt_delta(new['macro_f1'], base['macro_f1'])}"
    )
    L.append(
        f"- **GO recall:** {fmt_delta(new['metrics']['GO']['r'], base['metrics']['GO']['r'])} "
        f"(threshold for unblocking T-1737: ≥ {threshold_go_recall:.2f})"
    )
    L.append(
        f"- **Accuracy threshold for unblocking T-1737:** ≥ {threshold_acc:.0%}  → "
        f"{'PASS' if pass_acc else 'FAIL'}"
    )
    L.append(f"- **Latency p50:** {new['p50']:.0f}ms (vs T-1736 {base['p50']:.0f}ms)")
    L.append(f"- **Errors / parse-fails:** {new['errors']} / {new['parse_fails']}")
    L.append("")
    L.append("## Confusion matrix (T-1740 / new template)\n")
    L.append(render_confusion(new["confusion"]))
    L.append("")
    L.append("## Confusion matrix (T-1736 / baseline)\n")
    L.append(render_confusion(base["confusion"]))
    L.append("")
    L.append("## Per-class metrics — side-by-side delta\n")
    L.append("| class | metric | T-1736 (baseline) | T-1740 (revised) | Δ |")
    L.append("|---|---|---|---|---|")
    for c in CLASSES:
        for m in ("p", "r", "f1"):
            label = {"p": "precision", "r": "recall", "f1": "F1"}[m]
            old = base["metrics"][c][m]
            nw = new["metrics"][c][m]
            sym = "+" if nw - old >= 0 else ""
            L.append(
                f"| {c} | {label} | {old:.3f} | {nw:.3f} | {sym}{nw - old:+.3f} |"
            )
    L.append("")
    L.append("## Confidence calibration\n")
    L.append(
        f"- **Mean confidence on correct:** {new['conf_correct']:.3f} "
        f"(baseline {base['conf_correct']:.3f})"
    )
    L.append(
        f"- **Mean confidence on wrong:** {new['conf_wrong']:.3f} "
        f"(baseline {base['conf_wrong']:.3f})"
    )
    gap_new = new["conf_correct"] - new["conf_wrong"]
    gap_old = base["conf_correct"] - base["conf_wrong"]
    L.append(f"- **Gap (correct − wrong):** {gap_new:+.3f} (baseline {gap_old:+.3f})")
    L.append("")
    if new["disagreements"]:
        L.append("## Sample disagreements (new run)\n")
        for pid, t_label, v, rat in new["disagreements"][:10]:
            text = prompts.get(pid, {}).get("text", "?")[:140].replace("\n", " ")
            L.append(f"- **truth: {t_label}, pred: {v}** (`{pid}`)")
            L.append(f"  - prompt: `{text}`")
            L.append(f"  - rationale: {rat[:120]}")
        L.append("")
    L.append("## Threshold check\n")
    L.append(f"- Accuracy ≥ {threshold_acc:.0%}: **{pass_acc}**")
    L.append(f"- GO recall ≥ {threshold_go_recall:.2f}: **{pass_go_recall}**")
    L.append("")
    L.append("## Recommendation context\n")
    L.append("See task `## Recommendation` for the GO/NO-GO/DEFER call on unblocking T-1737.")

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(L) + "\n")
    print(f"report → {out_path}")
    print(f"new accuracy: {new['accuracy']:.2%} (Δ {new['accuracy'] - base['accuracy']:+.2%})")
    print(f"new GO recall: {new['metrics']['GO']['r']:.3f}")
    print(f"verdict: {verdict}")
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main())
