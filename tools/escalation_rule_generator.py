#!/usr/bin/env python3
"""
Escalation-scan auto-tuning: pattern detector and rule proposal engine.

Reads v0.5 verdicts from escalation-drift-LATEST-v0.5.yaml, detects FP patterns,
proposes exclusion rules with safeguard gates.

Usage:
    python3 tools/escalation-rule-generator.py [--dry-run] [--input FILE]

Design: docs/reports/T-1687-grilling-findings-telemetry-truncation.md
Origin: T-2494 (escalation-scan auto-tuning feedback loop, T-1687 grilling session)
"""

import argparse
import sys
import yaml
from pathlib import Path
from datetime import datetime, timedelta, timezone
from collections import defaultdict
import re

# Safeguard gates (from T-2494 AC)
MIN_CONFIDENCE = 0.95
MIN_SAMPLE_SIZE = 5
MIN_SPECIFICITY_ATTRS = 2  # Rule must have ≥2 distinguishing attributes

# Dry-run activation window
DRY_RUN_DAYS = 7


def load_verdicts(input_path):
    """Load v0.5 verdicts from YAML."""
    with open(input_path) as f:
        data = yaml.safe_load(f)
    return data


def extract_patterns(candidates):
    """
    Group false_positive verdicts by attribute combinations.

    Returns: dict of pattern_key -> list of candidate dicts
    """
    patterns = defaultdict(list)

    for cand in candidates:
        if cand.get('verdict') != 'false_positive':
            continue

        confidence = cand.get('confidence', 0.0)
        if confidence < MIN_CONFIDENCE:
            continue  # Skip low-confidence FPs

        # Extract attributes from rationale and title
        task_id = cand.get('task_id', '')
        name = cand.get('name', '')
        rationale = cand.get('rationale', '')

        # Pattern detection heuristics
        patterns_found = []

        # Pattern 1: title has "fix" but body shows "no code changes"
        if 'fix' in name.lower() and 'no code changes' in rationale.lower():
            patterns_found.append(('title:fix', 'body:no-code-changes'))

        # Pattern 2: title has "fix" but body is "doc edit"
        if 'fix' in name.lower() and 'doc edit' in rationale.lower():
            patterns_found.append(('title:fix', 'body:doc-edit'))

        # Pattern 3: title has "fix" but references existing RCA
        if 'fix' in name.lower() and 'existing rca report' in rationale.lower():
            patterns_found.append(('title:fix', 'body:existing-rca'))

        # Pattern 4: refactor with "fix" in title
        if 'fix' in name.lower() and 'refactor' in rationale.lower():
            patterns_found.append(('title:fix', 'body:refactor'))

        # Pattern 5: General "fix" title with explanatory rationale
        # (catch-all for title-only FPs where body explains why it's not a fix)
        if 'fix' in name.lower() and not patterns_found:
            patterns_found.append(('title:fix', 'body:explanatory'))

        # Add to patterns dict
        for pattern in patterns_found:
            pattern_key = ' + '.join(pattern)
            patterns[pattern_key].append(cand)

    return patterns


def apply_safeguards(patterns):
    """
    Filter patterns through safeguard gates.

    Gates:
    - confidence ≥0.95 (already filtered in extract_patterns)
    - sample_size ≥5
    - specificity ≥2 attributes

    Returns: dict of pattern_key -> candidate list for patterns that pass gates
    """
    filtered = {}

    for pattern_key, candidates in patterns.items():
        # Gate 1: Sample size
        if len(candidates) < MIN_SAMPLE_SIZE:
            continue

        # Gate 2: Specificity (≥2 attributes)
        attr_count = pattern_key.count(' + ') + 1
        if attr_count < MIN_SPECIFICITY_ATTRS:
            continue

        # Passed all gates
        filtered[pattern_key] = candidates

    return filtered


def generate_rules(filtered_patterns, dry_run=True):
    """
    Generate exclusion rules from filtered patterns.

    Returns: list of rule dicts ready for YAML serialization
    """
    rules = []
    now = datetime.now(timezone.utc)
    activates = now + timedelta(days=DRY_RUN_DAYS)

    for pattern_key, candidates in filtered_patterns.items():
        # Extract attributes from pattern key
        attrs = pattern_key.split(' + ')

        # Build rule dict
        rule = {
            'pattern': pattern_key,
            'attributes': {
                attr.split(':')[0]: attr.split(':')[1]
                for attr in attrs
            },
            'status': 'dry-run' if dry_run else 'proposed',
            'created': now.isoformat(),
            'activates': activates.isoformat(),
            'expires': None,  # Set by T-2496 lifecycle job
            'evidence': {
                'sample_size': len(candidates),
                'min_confidence': min(c.get('confidence', 0.0) for c in candidates),
                'avg_confidence': sum(c.get('confidence', 0.0) for c in candidates) / len(candidates),
                'task_ids': [c.get('task_id') for c in candidates],
            }
        }

        rules.append(rule)

    return rules


def write_rules(rules, output_path, dry_run=True):
    """Write rules to output YAML."""
    output = {
        'schema_version': '1.0',
        'generated': datetime.now(timezone.utc).isoformat(),
        'generator': 'escalation-rule-generator v1.0',
        'dry_run_mode': dry_run,
        'rules': rules,
    }

    with open(output_path, 'w') as f:
        yaml.dump(output, f, default_flow_style=False, sort_keys=False)

    return output_path


def main():
    parser = argparse.ArgumentParser(
        description='Escalation-scan pattern detector and rule proposal engine'
    )
    parser.add_argument(
        '--input',
        default='.context/working/escalation-drift-LATEST-v0.5.yaml',
        help='Input verdicts file (default: escalation-drift-LATEST-v0.5.yaml)'
    )
    parser.add_argument(
        '--output',
        default='.context/working/escalation-exclusion-rules.yaml',
        help='Output rules file (default: escalation-exclusion-rules.yaml)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what rules would be proposed without writing output'
    )

    args = parser.parse_args()

    # Load verdicts
    print(f"Loading verdicts from {args.input}...")
    data = load_verdicts(args.input)
    candidates = data.get('candidates', [])
    print(f"  Found {len(candidates)} candidates")

    # Extract patterns
    print("Extracting FP patterns...")
    patterns = extract_patterns(candidates)
    print(f"  Found {len(patterns)} raw patterns")

    # Apply safeguards
    print("Applying safeguard gates...")
    filtered = apply_safeguards(patterns)
    print(f"  {len(filtered)} patterns passed gates")

    # Generate rules
    print("Generating exclusion rules...")
    rules = generate_rules(filtered, dry_run=args.dry_run)
    print(f"  Generated {len(rules)} rules")

    if args.dry_run:
        print("\n=== DRY RUN - Rules that would be proposed ===")
        for i, rule in enumerate(rules, 1):
            print(f"\nRule {i}: {rule['pattern']}")
            print(f"  Sample size: {rule['evidence']['sample_size']}")
            print(f"  Confidence: {rule['evidence']['min_confidence']:.2f}-{rule['evidence']['avg_confidence']:.2f}")
            print(f"  Task IDs: {', '.join(rule['evidence']['task_ids'])}")
            print(f"  Status: {rule['status']}")
            print(f"  Activates: {rule['activates']}")
    else:
        # Write output
        output_path = write_rules(rules, args.output, dry_run=False)
        print(f"\n=== Rules written to {output_path} ===")
        print(f"Total rules: {len(rules)}")

    return 0


if __name__ == '__main__':
    sys.exit(main())
