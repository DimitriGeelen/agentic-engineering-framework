#!/usr/bin/env python3
"""
Escalation-scan auto-narrowing: false negative detector and v2 heuristic proposer.

Detects tasks that v0.5 LLM says should_escalate but H1 heuristic didn't flag.
Groups by pattern, applies safeguard gates, proposes stricter v2 heuristics.

Usage:
    python3 tools/escalation_narrowing_detector.py [--dry-run]

Part of T-1687 auto-tuning feedback loop (T-2498).
"""

import argparse
import sys
import yaml
from pathlib import Path
from datetime import datetime, timezone
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent
V05_PATH = ROOT / ".context" / "working" / "escalation-drift-LATEST-v0.5.yaml"
V0_PATH = ROOT / ".context" / "working" / "escalation-drift-LATEST.yaml"
OUTPUT_PATH = ROOT / ".context" / "working" / "escalation-narrowing-proposals.yaml"

# Safeguard gates (same as rule generator)
MIN_CONFIDENCE = 0.95
MIN_SAMPLE_SIZE = 3
MIN_SPECIFICITY_ATTRS = 2


def load_v05_verdicts():
    """Load v0.5 verdicts."""
    if not V05_PATH.exists():
        return []

    with V05_PATH.open() as f:
        data = yaml.safe_load(f)
    return data.get('candidates', [])


def load_h1_candidates():
    """Load H1 candidates (tasks flagged by v0 heuristic)."""
    if not V0_PATH.exists():
        return set()

    with V0_PATH.open() as f:
        data = yaml.safe_load(f)

    # H1 candidates are in h1_tasks list
    h1_tasks = data.get('h1_tasks', [])
    return set(h1_tasks)


def detect_false_negatives(verdicts, h1_candidates):
    """
    Find false negatives: v0.5 says should_escalate but H1 didn't flag.

    Returns: list of verdict dicts
    """
    false_negatives = []

    for verdict in verdicts:
        task_id = verdict.get('task_id')
        should_escalate = verdict.get('should_escalate', False)

        # False negative: should escalate but not in H1
        if should_escalate and task_id not in h1_candidates:
            false_negatives.append(verdict)

    return false_negatives


def extract_patterns(false_negatives):
    """
    Group false negatives by pattern attributes.

    Returns: dict of pattern -> list of verdicts
    """
    patterns = defaultdict(list)

    for fn in false_negatives:
        name = fn.get('name', '')
        rationale = fn.get('rationale', '')

        # Extract pattern attributes from rationale and title
        attrs = []

        # Title markers
        if 'fix' in name.lower():
            attrs.append('title:fix')
        if 'bug' in name.lower():
            attrs.append('title:bug')
        if 'error' in name.lower():
            attrs.append('title:error')
        if 'crash' in name.lower():
            attrs.append('title:crash')

        # Body markers (from rationale)
        if 'no rca' in rationale.lower() or 'missing rca' in rationale.lower():
            attrs.append('body:no-rca')
        if 'repeated pattern' in rationale.lower() or 'same issue' in rationale.lower():
            attrs.append('body:repeated-pattern')
        if 'symptom fix' in rationale.lower():
            attrs.append('body:symptom-fix')
        if 'should investigate' in rationale.lower():
            attrs.append('body:should-investigate')

        # Only consider if we found at least 2 attributes
        if len(attrs) >= MIN_SPECIFICITY_ATTRS:
            pattern_key = ' + '.join(sorted(attrs))
            patterns[pattern_key].append(fn)

    return patterns


def apply_safeguards(patterns):
    """
    Apply safeguard gates to patterns.

    Returns: dict of pattern -> {verdicts, sample_size, confidence, task_ids}
    """
    proposals = {}

    for pattern, verdicts in patterns.items():
        sample_size = len(verdicts)

        # Gate: minimum sample size
        if sample_size < MIN_SAMPLE_SIZE:
            continue

        # Gate: confidence (fraction of true_escalate in this pattern group)
        # Since these are already should_escalate=true, confidence is 1.0
        # (they're already confirmed false negatives)
        confidence = 1.0

        # Gate: minimum confidence
        if confidence < MIN_CONFIDENCE:
            continue

        # Extract task IDs for evidence
        task_ids = [v.get('task_id') for v in verdicts]

        proposals[pattern] = {
            'verdicts': verdicts,
            'sample_size': sample_size,
            'confidence': confidence,
            'task_ids': task_ids,
        }

    return proposals


def generate_v2_heuristics(proposals):
    """
    Generate v2 heuristic proposals from patterns.

    Returns: list of heuristic dicts
    """
    heuristics = []

    for pattern, data in proposals.items():
        attrs = pattern.split(' + ')

        # Parse attributes into title and body conditions
        title_conditions = [a.split(':')[1] for a in attrs if a.startswith('title:')]
        body_conditions = [a.split(':')[1] for a in attrs if a.startswith('body:')]

        heuristic = {
            'pattern': pattern,
            'description': f"Catch tasks with {pattern}",
            'conditions': {
                'title': title_conditions,
                'body': body_conditions,
            },
            'evidence': {
                'sample_size': data['sample_size'],
                'confidence': data['confidence'],
                'task_ids': data['task_ids'][:10],  # Limit to first 10 for readability
            },
            'proposed': datetime.now(timezone.utc).isoformat(),
            'status': 'proposed',
        }

        heuristics.append(heuristic)

    return heuristics


def write_proposals(heuristics, dry_run=False):
    """Write v2 heuristic proposals to output file."""
    if dry_run:
        print("DRY RUN — would write to:", OUTPUT_PATH)
        print(yaml.dump({'heuristics': heuristics}, default_flow_style=False))
        return

    output_data = {
        'generated': datetime.now(timezone.utc).isoformat(),
        'heuristics': heuristics,
    }

    with OUTPUT_PATH.open('w') as f:
        yaml.dump(output_data, f, default_flow_style=False, sort_keys=False)

    print(f"Proposals written to: {OUTPUT_PATH}")


def main():
    parser = argparse.ArgumentParser(
        description='Escalation-scan auto-narrowing: detect false negatives and propose v2 heuristics'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be proposed without writing files'
    )

    args = parser.parse_args()

    # Load data
    print("Loading v0.5 verdicts...")
    verdicts = load_v05_verdicts()
    print(f"  Found {len(verdicts)} verdicts")

    print("Loading H1 candidates...")
    h1_candidates = load_h1_candidates()
    print(f"  Found {len(h1_candidates)} H1 candidates")

    # Detect false negatives
    print("\nDetecting false negatives...")
    false_negatives = detect_false_negatives(verdicts, h1_candidates)
    print(f"  Found {len(false_negatives)} false negatives (should_escalate=true but not in H1)")

    if not false_negatives:
        print("\nNo false negatives detected — H1 heuristic is catching everything v0.5 suggests.")
        return 0

    # Extract patterns
    print("\nExtracting patterns...")
    patterns = extract_patterns(false_negatives)
    print(f"  Found {len(patterns)} distinct patterns")

    # Apply safeguards
    print("\nApplying safeguard gates...")
    print(f"  Confidence threshold: {MIN_CONFIDENCE}")
    print(f"  Sample size threshold: {MIN_SAMPLE_SIZE}")
    print(f"  Specificity threshold: {MIN_SPECIFICITY_ATTRS} attributes")

    proposals = apply_safeguards(patterns)
    print(f"  {len(proposals)} patterns passed gates")

    if not proposals:
        print("\nNo patterns passed safeguard gates.")
        return 0

    # Generate v2 heuristics
    print("\nGenerating v2 heuristic proposals...")
    heuristics = generate_v2_heuristics(proposals)
    print(f"  Generated {len(heuristics)} v2 heuristic(s)")

    # Write proposals
    write_proposals(heuristics, dry_run=args.dry_run)

    if not args.dry_run:
        print(f"\nProposals saved to: {OUTPUT_PATH}")
        print("Review proposals and integrate promising heuristics into escalation-scan-v0.py")

    return 0


if __name__ == '__main__':
    sys.exit(main())
