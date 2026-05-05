#!/usr/bin/env python3
"""T-1743 Spike-D off-ramp: re-score 4-model results as binary GO / non-GO.

Collapses DEFER labels into NO-GO in both truth and predictions, re-computes
accuracy + GO precision/recall + F1 per model. No new inference — pure
re-score of existing .context/spikes/T-{1740,1741}-*-results.jsonl files.

If any model's binary accuracy clears 90% AND GO recall + precision both
clear 0.85, T-1737 (Slice 2 hook) can unblock with a binary classifier.
"""
import json
from pathlib import Path

import yaml


RUNS = [
    ("hermes3", ".context/spikes/T-1740-results.jsonl"),
    ("qwen3", ".context/spikes/T-1741-qwen3-results.jsonl"),
    ("qwen35", ".context/spikes/T-1741-qwen35-results.jsonl"),
    ("gemma4", ".context/spikes/T-1741-gemma4-results.jsonl"),
]
LABELS_PATH = ".context/spikes/T-1736-labels.yaml"
OUT_PATH = "docs/reports/T-1743-binary-rescore.md"


def to_binary(label: str) -> str:
    return "GO" if label == "GO" else "NON_GO"


def score(truth_bin: dict[str, str], preds: dict[str, dict]) -> dict:
    tp = fp = fn = tn = parse_fails = errors = 0
    for pid, t in truth_bin.items():
        if pid not in preds:
            errors += 1
            continue
        r = preds[pid]
        if not r.get("ok"):
            errors += 1
            continue
        v = r.get("verdict") or ""
        if v not in ("GO", "NO-GO", "DEFER"):
            parse_fails += 1
            continue
        v_bin = "GO" if v == "GO" else "NON_GO"
        if t == "GO" and v_bin == "GO":
            tp += 1
        elif t == "GO" and v_bin == "NON_GO":
            fn += 1
        elif t == "NON_GO" and v_bin == "GO":
            fp += 1
        else:
            tn += 1
    n = tp + fp + fn + tn
    acc = (tp + tn) / n if n else 0.0
    p_go = tp / (tp + fp) if (tp + fp) else 0.0
    r_go = tp / (tp + fn) if (tp + fn) else 0.0
    f1_go = 2 * p_go * r_go / (p_go + r_go) if (p_go + r_go) else 0.0
    p_ng = tn / (tn + fn) if (tn + fn) else 0.0
    r_ng = tn / (tn + fp) if (tn + fp) else 0.0
    f1_ng = 2 * p_ng * r_ng / (p_ng + r_ng) if (p_ng + r_ng) else 0.0
    return {
        "tp": tp, "fp": fp, "fn": fn, "tn": tn, "n": n,
        "acc": acc,
        "p_go": p_go, "r_go": r_go, "f1_go": f1_go,
        "p_ng": p_ng, "r_ng": r_ng, "f1_ng": f1_ng,
        "macro_f1": (f1_go + f1_ng) / 2,
        "parse_fails": parse_fails,
        "errors": errors,
    }


def main() -> int:
    truth = yaml.safe_load(Path(LABELS_PATH).read_text())
    truth_bin = {e["id"]: to_binary(e["label"]) for e in truth}
    n_go = sum(1 for v in truth_bin.values() if v == "GO")
    always_go = n_go / len(truth_bin) if truth_bin else 0.0

    results = []
    for label, path in RUNS:
        p = Path(path)
        if not p.exists():
            results.append((label, path, None))
            continue
        preds = {}
        for line in p.open():
            r = json.loads(line)
            preds[r["id"]] = r
        results.append((label, path, score(truth_bin, preds)))

    completed = [(l, p, r) for l, p, r in results if r is not None]
    best = max(completed, key=lambda x: (x[2]["acc"], x[2]["f1_go"])) if completed else None

    L = []
    L.append("# T-1743 Spike-D binary re-score — drop DEFER, re-frame as GO / non-GO\n")
    L.append("Collapses DEFER labels into NO-GO in both truth and predictions, re-scores")
    L.append("the four T-1741 result files. No new inference. Question: if we drop the")
    L.append("DEFER class (consistently weakest signal across all 4 models in Spike D),")
    L.append("can a binary classifier clear T-1737 unblock thresholds?\n")
    L.append("**Binary thresholds (proposed):** accuracy >= 0.90 AND GO recall >= 0.85 AND GO precision >= 0.85\n")
    L.append(f"**Always-GO baseline (binary):** {always_go:.2%} ({n_go}/{len(truth_bin)} prompts)\n")
    L.append("## Headline\n")
    L.append("| model | acc | GO P | GO R | GO F1 | NON_GO F1 | macro F1 | parse-fails |")
    L.append("|---|---|---|---|---|---|---|---|")
    for label, path, r in results:
        if r is None:
            L.append(f"| {label} | — | — | — | — | — | — | (no file) |")
            continue
        L.append(
            f"| {label} | {r['acc']:.2%} | {r['p_go']:.3f} | {r['r_go']:.3f} | "
            f"{r['f1_go']:.3f} | {r['f1_ng']:.3f} | {r['macro_f1']:.3f} | {r['parse_fails']} |"
        )
    L.append("")
    if best:
        bl, _, br = best
        L.append(f"**Best by accuracy:** **{bl}** (acc={br['acc']:.2%}, GO F1={br['f1_go']:.3f})\n")
        passes = (br['acc'] >= 0.90 and br['r_go'] >= 0.85 and br['p_go'] >= 0.85)
        if passes:
            L.append(f"## Verdict: GO\n\n**{bl}** clears all binary thresholds. Binary classifier is viable. T-1737 can unblock with a 2-class formulation (GO unblocks prompt; NON_GO triggers framework intervention).")
        else:
            failing = []
            if br['acc'] < 0.90:
                failing.append(f"accuracy {br['acc']:.2%} < 90%")
            if br['r_go'] < 0.85:
                failing.append(f"GO recall {br['r_go']:.3f} < 0.85")
            if br['p_go'] < 0.85:
                failing.append(f"GO precision {br['p_go']:.3f} < 0.85")
            L.append(f"## Verdict: NO-GO\n\nBest model ({bl}) does not clear all binary thresholds. Failing: {'; '.join(failing)}.")
            L.append("\nBinary reframe does not rescue T-1737. The architectural concern (3-class signal too noisy on 7-8B local model) propagates to binary as well. Recommend T-1744 (different G-064 first-consumer) over T-1742 (qwen35 max_tokens spike).")
    L.append("")
    L.append("## Per-model confusion (binary)\n")
    for label, path, r in results:
        if r is None:
            continue
        L.append(f"### {label}")
        L.append(f"- TP (GO->GO): {r['tp']}  ·  FN (GO->NON_GO): {r['fn']}")
        L.append(f"- FP (NON_GO->GO): {r['fp']}  ·  TN (NON_GO->NON_GO): {r['tn']}")
        L.append(f"- accuracy: {r['acc']:.2%}  ·  parse-fails: {r['parse_fails']}  ·  errors: {r['errors']}")
        L.append("")

    out = Path(OUT_PATH)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(L) + "\n")
    print(f"report -> {out}")
    if best:
        bl, _, br = best
        print(f"best: {bl} acc={br['acc']:.2%} GO_F1={br['f1_go']:.3f}")
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
