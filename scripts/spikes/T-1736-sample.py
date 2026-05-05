#!/usr/bin/env python3
"""Sample 50 prompts from the harvest, stratified across source projects.

Outputs a labeling skeleton (YAML) ready for hand-labeling, plus a
trimmed prompts subset for the run-harness.
"""
import argparse
import json
import random
from collections import defaultdict
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", default=".context/spikes/T-1736-prompts.jsonl")
    ap.add_argument("--out-prompts", default=".context/spikes/T-1736-sampled.jsonl")
    ap.add_argument("--out-labels", default=".context/spikes/T-1736-labels.yaml")
    ap.add_argument("--n", type=int, default=50)
    ap.add_argument("--seed", type=int, default=1736)
    ap.add_argument("--min-len", type=int, default=40)
    ap.add_argument("--max-len", type=int, default=2000)
    args = ap.parse_args()

    rng = random.Random(args.seed)
    by_project: dict[str, list[dict]] = defaultdict(list)
    for line in Path(args.inp).open():
        p = json.loads(line)
        if not (args.min_len <= len(p["text"]) <= args.max_len):
            continue
        proj = p["source"].split("/")[1] if "/" in p["source"] else "?"
        by_project[proj].append(p)

    # Stratified: take roughly equal share per project
    n = args.n
    n_projects = len(by_project)
    per = max(1, n // n_projects)
    picked: list[dict] = []
    for proj, prompts in sorted(by_project.items()):
        rng.shuffle(prompts)
        picked.extend(prompts[:per])
    rng.shuffle(picked)
    if len(picked) > n:
        picked = picked[:n]
    elif len(picked) < n:
        # backfill from the largest pool
        all_remaining = []
        picked_ids = {p["id"] for p in picked}
        for prompts in by_project.values():
            all_remaining.extend(p for p in prompts if p["id"] not in picked_ids)
        rng.shuffle(all_remaining)
        picked.extend(all_remaining[: n - len(picked)])

    # Write sampled prompts
    Path(args.out_prompts).parent.mkdir(parents=True, exist_ok=True)
    with Path(args.out_prompts).open("w") as f:
        for p in picked:
            f.write(json.dumps(p, ensure_ascii=False) + "\n")

    # Emit labeling skeleton (YAML)
    out_yaml = Path(args.out_labels)
    if out_yaml.exists():
        print(f"WARN: {out_yaml} exists, not overwriting")
    else:
        with out_yaml.open("w") as f:
            f.write("# T-1736 ground-truth labels (hand-labeled)\n")
            f.write("# label ∈ {GO, NO-GO, DEFER}; see prompts/prompt-triage.md\n")
            f.write("# GO = substantive change requested; NO-GO = read-only/conversational; DEFER = genuinely ambiguous\n")
            for p in picked:
                # Heuristic seed: short answer-style → NO-GO; long action-style → GO
                preview = p["text"].replace("\n", " ").replace("'", "''")[:100]
                f.write(
                    f"- id: {p['id']}\n"
                    f"  label: TODO\n"
                    f"  preview: '{preview}'\n"
                )
    print(f"sampled {len(picked)} prompts → {args.out_prompts}")
    print(f"label skeleton → {args.out_labels}")
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main())
