#!/usr/bin/env python3
"""
T-2494 — Escalation-scan auto-tuning: pattern detector and rule proposal engine.

Reads escalation-drift-LATEST-v0.5.yaml, detects false-positive patterns, and
proposes exclusion rules to tighten the heuristic. Applies safeguard gates to
prevent over-broad rules.

Safeguard gates:
  - Confidence ≥0.95 (all samples in group must have confidence ≥0.95)
  - Sample size ≥5 (minimum group size)
  - Specificity ≥2 attributes (pattern must match on at least 2 distinct attributes)

Output: .context/working/escalation-exclusion-rules.yaml
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml

ROOT = Path(os.environ.get("PROJECT_ROOT", os.getcwd())).resolve()
V05_LATEST = ROOT / ".context" / "working" / "escalation-drift-LATEST-v0.5.yaml"
OUTPUT_PATH = ROOT / ".context" / "working" / "escalation-exclusion-rules.yaml"

# Pattern extraction regexes
WORKFLOW_TYPE_RE = re.compile(r"workflow_type[:\s]+(\w+)")
TITLE_PATTERN_RE = re.compile(r"\b(fix|bug|rca|broken|crash|error|regression|fail|hotfix)\b", re.I)


def load_v05_yaml() -> dict:
    """Load escalation-drift-LATEST-v0.5.yaml."""
    if not V05_LATEST.exists():
        sys.stderr.write(
            f"ERROR: {V05_LATEST.relative_to(ROOT)} not found.\n"
            f"Run tools/escalation-scan-v0.5.py first.\n"
        )
        sys.exit(2)
    return yaml.safe_load(V05_LATEST.read_text()) or {}


def extract_attributes(candidate: dict) -> dict:
    """Extract attributes from a candidate for pattern grouping."""
    attrs = {}
    
    # Workflow type (if we had frontmatter parsing, we'd extract it properly)
    # For now, we'll extract from name/title patterns
    name = candidate.get("name", "")
    
    # Check for common workflow type signals in title
    if re.search(r"\binception\b", name, re.I):
        attrs["workflow_type"] = "inception"
    elif re.search(r"\bdesign\b", name, re.I):
        attrs["workflow_type"] = "design"
    elif re.search(r"\bspec\b|specification", name, re.I):
        attrs["workflow_type"] = "specification"
    else:
        attrs["workflow_type"] = "build"  # default assumption
    
    # Title pattern - check for fix/bug keywords
    has_fix_keyword = bool(TITLE_PATTERN_RE.search(name))
    attrs["has_fix_keyword"] = has_fix_keyword
    
    # Check for specific patterns in title
    if re.search(r"\brefresh\b|\bupdate\b", name, re.I):
        attrs["is_refresh_or_update"] = True
    if re.search(r"\brca\b", name, re.I):
        attrs["mentions_rca"] = True
    if re.search(r"\bdoc\b|documentation", name, re.I):
        attrs["is_doc_task"] = True
    if re.search(r"\brefactor\b", name, re.I):
        attrs["is_refactor"] = True
    
    return attrs


def count_attributes(attrs: dict) -> int:
    """Count number of non-None/non-False attributes."""
    return sum(1 for v in attrs.values() if v and v != "build")


def group_false_positives(candidates: list[dict]) -> dict[str, list[dict]]:
    """Group false_positive verdicts by attribute combinations."""
    groups = defaultdict(list)
    
    for candidate in candidates:
        if candidate.get("verdict") != "false_positive":
            continue
        
        attrs = extract_attributes(candidate)
        
        # Create a hashable key from attributes
        # We want to group by meaningful combinations
        key_parts = []
        
        workflow = attrs.get("workflow_type")
        if workflow and workflow != "build":
            key_parts.append(f"workflow:{workflow}")
        
        if attrs.get("has_fix_keyword"):
            key_parts.append("has_fix_keyword")
        
        if attrs.get("is_refresh_or_update"):
            key_parts.append("is_refresh_or_update")
        
        if attrs.get("mentions_rca"):
            key_parts.append("mentions_rca")
        
        if attrs.get("is_doc_task"):
            key_parts.append("is_doc_task")
        
        if attrs.get("is_refactor"):
            key_parts.append("is_refactor")
        
        # Only group if we have at least 2 attributes
        if len(key_parts) >= 2:
            key = ",".join(sorted(key_parts))
            groups[key].append(candidate)
    
    return groups


def apply_safeguard_gates(groups: dict[str, list[dict]]) -> list[dict]:
    """Apply safeguard gates and return proposed rules."""
    proposed_rules = []
    
    for pattern_key, candidates in groups.items():
        # Gate 1: Sample size ≥5
        if len(candidates) < 5:
            continue
        
        # Gate 2: Confidence ≥0.95 (all samples must meet threshold)
        confidences = [c.get("confidence", 0.0) for c in candidates]
        if any(conf < 0.95 for conf in confidences):
            continue
        
        # Gate 3: Specificity ≥2 attributes (already enforced during grouping)
        attributes = pattern_key.split(",")
        if len(attributes) < 2:
            continue
        
        # Build rule
        rule = {
            "pattern": pattern_key,
            "attributes": attributes,
            "evidence": {
                "sample_size": len(candidates),
                "min_confidence": min(confidences),
                "max_confidence": max(confidences),
                "avg_confidence": sum(confidences) / len(confidences),
                "task_ids": [c.get("task_id") for c in candidates],
            },
            "status": "dry-run",
            "activates": (datetime.now(timezone.utc) + timedelta(days=7)).isoformat(),
            "created": datetime.now(timezone.utc).isoformat(),
        }
        
        proposed_rules.append(rule)
    
    return proposed_rules


def format_output(rules: list[dict]) -> dict:
    """Format rules into output YAML structure."""
    return {
        "generated": datetime.now(timezone.utc).isoformat(),
        "source": str(V05_LATEST.relative_to(ROOT)),
        "safeguard_gates": {
            "min_confidence": 0.95,
            "min_sample_size": 5,
            "min_specificity_attributes": 2,
        },
        "rules_proposed": len(rules),
        "rules": rules,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Escalation-scan auto-tuning: pattern detector and rule proposal engine"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what rules would be proposed without writing output file",
    )
    parser.add_argument(
        "--min-confidence",
        type=float,
        default=0.95,
        help="Minimum confidence threshold for rules (default: 0.95)",
    )
    parser.add_argument(
        "--min-samples",
        type=int,
        default=5,
        help="Minimum sample size for rules (default: 5)",
    )
    args = parser.parse_args()
    
    # Load v0.5 verdicts
    v05_data = load_v05_yaml()
    candidates = v05_data.get("candidates", [])
    
    if not candidates:
        print("No candidates found in v0.5 output. Nothing to analyze.")
        return 0
    
    # Count verdict breakdown
    verdict_counts = defaultdict(int)
    for c in candidates:
        verdict_counts[c.get("verdict", "unknown")] += 1
    
    print(f"Loaded {len(candidates)} candidates from {V05_LATEST.relative_to(ROOT)}")
    print(f"Verdict breakdown:")
    for verdict, count in sorted(verdict_counts.items()):
        print(f"  {verdict}: {count}")
    print()
    
    # Group false positives
    groups = group_false_positives(candidates)
    print(f"Found {len(groups)} distinct patterns (before gates)")
    print()
    
    # Apply safeguard gates
    proposed_rules = apply_safeguard_gates(groups)
    
    if not proposed_rules:
        print("No patterns met all safeguard gates (confidence ≥0.95, samples ≥5, specificity ≥2).")
        print("No rules to propose.")
        return 0
    
    print(f"After applying safeguard gates: {len(proposed_rules)} rules proposed")
    print()
    
    # Format output
    output_data = format_output(proposed_rules)
    
    if args.dry_run:
        print("DRY RUN MODE — would write to:", OUTPUT_PATH.relative_to(ROOT))
        print()
        print(yaml.dump(output_data, sort_keys=False, default_flow_style=False))
        return 0
    
    # Write output
    OUTPUT_PATH.write_text(yaml.dump(output_data, sort_keys=False, default_flow_style=False))
    print(f"Wrote {len(proposed_rules)} proposed rules to {OUTPUT_PATH.relative_to(ROOT)}")
    
    # Show summary
    print()
    print("Proposed rules summary:")
    for i, rule in enumerate(proposed_rules, 1):
        print(f"  {i}. {rule['pattern']}")
        print(f"     Samples: {rule['evidence']['sample_size']}, "
              f"Confidence: {rule['evidence']['min_confidence']:.2f}-{rule['evidence']['max_confidence']:.2f}")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
