#!/usr/bin/env python3
"""Memory consolidation engine for the Agentic Engineering Framework.

Detects duplicate and stale learnings/patterns in project memory files.
Generates consolidation reports and applies approved changes.

Usage:
    consolidate.py scan [--threshold N] [--output FILE]
    consolidate.py apply [--report FILE] [--no-backup]
    consolidate.py report [--file FILE]

Design principles:
    - Dry-run by default (scan never modifies source files)
    - File-based (D4 Portability) — no external dependencies beyond PyYAML
    - Deterministic (D2 Reliability) — heuristic text similarity, not LLM
    - Safe — backup before any modification
"""

import argparse
import copy
import os
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone

import yaml


# ---------------------------------------------------------------------------
# Text similarity (Jaccard on word tokens)
# ---------------------------------------------------------------------------

STOP_WORDS = frozenset(
    "a an the is was were be been being have has had do does did will would "
    "shall should may might can could of in to for on with at by from as into "
    "through during before after above below between under and but or nor not "
    "so yet both either neither each every all any few more most other some "
    "such no only own same than too very that this these those it its he she "
    "they them their his her who which what when where how".split()
)


def tokenize(text):
    """Lowercase, strip punctuation, remove stop words."""
    if not text:
        return set()
    words = re.findall(r"[a-z0-9]+", text.lower())
    return {w for w in words if w not in STOP_WORDS and len(w) > 2}


def jaccard(set_a, set_b):
    """Jaccard similarity coefficient."""
    if not set_a or not set_b:
        return 0.0
    intersection = set_a & set_b
    union = set_a | set_b
    return len(intersection) / len(union)


def learning_tokens(entry):
    """Extract combined token set from a learning entry."""
    parts = []
    for field in ("learning", "context", "application"):
        val = entry.get(field, "")
        if val and val != "TBD":
            parts.append(str(val))
    return tokenize(" ".join(parts))


def pattern_tokens(entry):
    """Extract combined token set from a pattern entry."""
    parts = []
    for field in ("pattern", "description", "mitigation"):
        val = entry.get(field, "")
        if val:
            parts.append(str(val))
    return tokenize(" ".join(parts))


# ---------------------------------------------------------------------------
# Duplicate detection
# ---------------------------------------------------------------------------

def primary_field_tokens(entry):
    """Extract tokens from just the primary text field (learning or pattern)."""
    text = entry.get("learning", entry.get("pattern", ""))
    return tokenize(str(text)) if text else set()


def find_duplicate_clusters(entries, token_fn, threshold=0.35):
    """Find clusters of semantically similar entries.

    Uses dual similarity: checks both full-field and primary-field-only similarity.
    If either exceeds the threshold, entries are considered duplicates.
    This catches cases where entries describe the same learning but have
    different context/application richness.

    Returns list of clusters, each cluster is a list of (entry, similarity_to_first).
    """
    n = len(entries)
    if n == 0:
        return []

    # Precompute tokens (full and primary-only)
    tokens_full = [token_fn(e) for e in entries]
    tokens_primary = [primary_field_tokens(e) for e in entries]

    # Build adjacency list of similar pairs
    adj = defaultdict(set)
    pair_sim = {}
    for i in range(n):
        for j in range(i + 1, n):
            sim_full = jaccard(tokens_full[i], tokens_full[j])
            sim_primary = jaccard(tokens_primary[i], tokens_primary[j])
            sim = max(sim_full, sim_primary)
            if sim >= threshold:
                adj[i].add(j)
                adj[j].add(i)
                pair_sim[(i, j)] = sim

    # Connected components via BFS
    visited = set()
    clusters = []
    for start in range(n):
        if start in visited or start not in adj:
            continue
        cluster_indices = []
        queue = [start]
        while queue:
            node = queue.pop(0)
            if node in visited:
                continue
            visited.add(node)
            cluster_indices.append(node)
            for neighbor in adj[node]:
                if neighbor not in visited:
                    queue.append(neighbor)

        if len(cluster_indices) >= 2:
            # Sort by richness (more tokens = richer)
            cluster_indices.sort(key=lambda idx: -len(tokens_full[idx]))
            best = cluster_indices[0]
            cluster = []
            for idx in cluster_indices:
                if idx == best:
                    sim = 1.0
                else:
                    pair = (min(best, idx), max(best, idx))
                    sim = pair_sim.get(pair, 0.0)
                cluster.append({
                    "id": entries[idx].get("id", "?"),
                    "text": entries[idx].get("learning", entries[idx].get("pattern", "?")),
                    "similarity": round(sim, 3),
                    "is_richest": idx == best,
                    "token_count": len(tokens_full[idx]),
                })
            clusters.append(cluster)

    return clusters


# ---------------------------------------------------------------------------
# Staleness detection
# ---------------------------------------------------------------------------

def find_stale_learnings(learnings):
    """Detect learnings that may be stale or under-contextualized."""
    stale = []
    for entry in learnings:
        reasons = []
        lid = entry.get("id", "?")

        # TBD application — never fully contextualized
        app = entry.get("application", "")
        if app == "TBD" or not app:
            reasons.append("application field is TBD or empty")

        # Very old entries without promotion
        date_str = entry.get("date")
        if date_str:
            try:
                if isinstance(date_str, str):
                    d = datetime.strptime(date_str, "%Y-%m-%d")
                else:
                    d = datetime.combine(date_str, datetime.min.time())
                age_days = (datetime.now() - d).days
                if age_days > 14:
                    candidates = entry.get("candidates", [])
                    if not candidates:
                        reasons.append(f"older than 14 days ({age_days}d) with no promotion candidates")
            except (ValueError, TypeError):
                pass

        if reasons:
            stale.append({
                "id": lid,
                "text": entry.get("learning", "?")[:120],
                "reasons": reasons,
            })

    return stale


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def generate_report(learnings_path, patterns_path, threshold, output_path):
    """Scan memory files and generate consolidation report."""
    report = {
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "threshold": threshold,
        "sources": {
            "learnings": learnings_path,
            "patterns": patterns_path,
        },
        "summary": {},
        "duplicate_clusters": {"learnings": [], "patterns": []},
        "stale_entries": [],
        "recommendations": [],
    }

    # Load learnings
    learnings = []
    if os.path.exists(learnings_path):
        with open(learnings_path) as f:
            data = yaml.safe_load(f) or {}
        learnings = data.get("learnings", []) or []

    # Load patterns (all categories)
    all_patterns = []
    if os.path.exists(patterns_path):
        with open(patterns_path) as f:
            pdata = yaml.safe_load(f) or {}
        for key in ("failure_patterns", "success_patterns", "antifragile_patterns", "workflow_patterns"):
            entries = pdata.get(key, []) or []
            for e in entries:
                e["_category"] = key
            all_patterns.extend(entries)

    # Duplicate detection
    learning_clusters = find_duplicate_clusters(learnings, learning_tokens, threshold)
    pattern_clusters = find_duplicate_clusters(all_patterns, pattern_tokens, threshold)

    report["duplicate_clusters"]["learnings"] = learning_clusters
    report["duplicate_clusters"]["patterns"] = pattern_clusters

    # Staleness detection
    stale = find_stale_learnings(learnings)
    report["stale_entries"] = stale

    # Summary
    total_dup_learnings = sum(len(c) for c in learning_clusters)
    total_dup_patterns = sum(len(c) for c in pattern_clusters)
    report["summary"] = {
        "total_learnings": len(learnings),
        "total_patterns": len(all_patterns),
        "duplicate_clusters_learnings": len(learning_clusters),
        "duplicate_entries_learnings": total_dup_learnings,
        "duplicate_clusters_patterns": len(pattern_clusters),
        "duplicate_entries_patterns": total_dup_patterns,
        "stale_entries": len(stale),
    }

    # Recommendations
    recs = []
    for cluster in learning_clusters:
        richest = [e for e in cluster if e["is_richest"]][0]
        others = [e for e in cluster if not e["is_richest"]]
        other_ids = ", ".join(e["id"] for e in others)
        recs.append({
            "action": "merge",
            "target": "learnings",
            "keep": richest["id"],
            "remove": [e["id"] for e in others],
            "reason": f"Duplicate cluster: keep {richest['id']} (richest), remove {other_ids}",
        })

    for entry in stale:
        if "application field is TBD" in " ".join(entry["reasons"]):
            recs.append({
                "action": "enrich_or_prune",
                "target": "learnings",
                "id": entry["id"],
                "reason": f"{entry['id']} has TBD application — enrich with context or prune",
            })

    report["recommendations"] = recs

    # Write report
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        yaml.dump(report, f, default_flow_style=False, sort_keys=False, allow_unicode=True, width=120)

    return report


# ---------------------------------------------------------------------------
# Apply consolidation
# ---------------------------------------------------------------------------

def apply_report(report_path, no_backup=False):
    """Apply merge recommendations from a consolidation report."""
    if not os.path.exists(report_path):
        print(f"Error: Report not found: {report_path}", file=sys.stderr)
        return 1

    with open(report_path) as f:
        report = yaml.safe_load(f)

    learnings_path = report["sources"]["learnings"]
    if not os.path.exists(learnings_path):
        print(f"Error: Learnings file not found: {learnings_path}", file=sys.stderr)
        return 1

    # Backup
    if not no_backup:
        backup_path = learnings_path + f".backup-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        with open(learnings_path) as src:
            content = src.read()
        with open(backup_path, "w") as dst:
            dst.write(content)
        print(f"Backup: {backup_path}")

    # Load current learnings
    with open(learnings_path) as f:
        data = yaml.safe_load(f) or {}
    learnings = data.get("learnings", []) or []

    # Collect IDs to remove from merge recommendations
    remove_ids = set()
    for rec in report.get("recommendations", []):
        if rec.get("action") == "merge" and rec.get("target") == "learnings":
            for rid in rec.get("remove", []):
                remove_ids.add(rid)

    if not remove_ids:
        print("No merge actions to apply.")
        return 0

    # Filter out removed entries
    original_count = len(learnings)
    learnings = [l for l in learnings if l.get("id") not in remove_ids]
    removed_count = original_count - len(learnings)

    # Write back
    data["learnings"] = learnings
    # Preserve the file header comment
    header = "# Project Memory - Learnings\n# Lessons learned from completed tasks.\n# Used by agents to improve future work.\n\n"
    with open(learnings_path, "w") as f:
        f.write(header)
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True, width=120)

    print(f"Applied: removed {removed_count} duplicate learnings (kept richest from each cluster)")
    print(f"Remaining: {len(learnings)} learnings")
    return 0


# ---------------------------------------------------------------------------
# Display report
# ---------------------------------------------------------------------------

def display_report(report_path):
    """Display consolidation report in human-readable format."""
    if not os.path.exists(report_path):
        print(f"Error: Report not found: {report_path}", file=sys.stderr)
        return 1

    with open(report_path) as f:
        report = yaml.safe_load(f)

    summary = report.get("summary", {})
    print(f"=== Memory Consolidation Report ===")
    print(f"Generated: {report.get('generated', '?')}")
    print(f"Threshold: {report.get('threshold', '?')}")
    print()
    print(f"Learnings: {summary.get('total_learnings', 0)} total, "
          f"{summary.get('duplicate_clusters_learnings', 0)} duplicate clusters "
          f"({summary.get('duplicate_entries_learnings', 0)} entries)")
    print(f"Patterns:  {summary.get('total_patterns', 0)} total, "
          f"{summary.get('duplicate_clusters_patterns', 0)} duplicate clusters "
          f"({summary.get('duplicate_entries_patterns', 0)} entries)")
    print(f"Stale:     {summary.get('stale_entries', 0)} entries")
    print()

    # Duplicate clusters
    for label, key in [("Learning", "learnings"), ("Pattern", "patterns")]:
        clusters = report.get("duplicate_clusters", {}).get(key, [])
        if clusters:
            print(f"--- {label} Duplicate Clusters ---")
            for i, cluster in enumerate(clusters, 1):
                print(f"\n  Cluster {i}:")
                for entry in cluster:
                    marker = " [KEEP]" if entry.get("is_richest") else " [REMOVE]"
                    sim = entry.get("similarity", 0)
                    text = entry.get("text", "?")
                    if len(text) > 80:
                        text = text[:77] + "..."
                    print(f"    {entry['id']}{marker} (sim={sim:.2f}, tokens={entry.get('token_count', 0)})")
                    print(f"      \"{text}\"")
            print()

    # Stale entries
    stale = report.get("stale_entries", [])
    if stale:
        print("--- Stale Entries ---")
        for entry in stale:
            reasons = ", ".join(entry.get("reasons", []))
            print(f"  {entry['id']}: {reasons}")
            text = entry.get("text", "?")
            if len(text) > 80:
                text = text[:77] + "..."
            print(f"    \"{text}\"")
        print()

    # Recommendations
    recs = report.get("recommendations", [])
    if recs:
        print(f"--- Recommendations ({len(recs)}) ---")
        for i, rec in enumerate(recs, 1):
            print(f"  {i}. [{rec.get('action', '?')}] {rec.get('reason', '?')}")
        print()
        print("Run 'fw consolidate apply' to execute merge recommendations.")

    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Memory consolidation engine")
    subparsers = parser.add_subparsers(dest="command")

    # scan
    scan_p = subparsers.add_parser("scan", help="Scan for duplicates and stale entries")
    scan_p.add_argument("--threshold", type=float, default=0.35,
                        help="Jaccard similarity threshold (default: 0.35)")
    scan_p.add_argument("--output", default=None,
                        help="Output report path")

    # apply
    apply_p = subparsers.add_parser("apply", help="Apply consolidation from report")
    apply_p.add_argument("--report", default=None, help="Report file path")
    apply_p.add_argument("--no-backup", action="store_true", help="Skip backup")

    # report
    report_p = subparsers.add_parser("report", help="Display last report")
    report_p.add_argument("--file", default=None, help="Report file path")

    args = parser.parse_args()

    # Resolve paths relative to project root
    project_root = os.environ.get("PROJECT_ROOT", os.getcwd())
    learnings_path = os.path.join(project_root, ".context", "project", "learnings.yaml")
    patterns_path = os.path.join(project_root, ".context", "project", "patterns.yaml")
    default_report = os.path.join(project_root, ".context", "working", "consolidation-report.yaml")

    if args.command == "scan":
        output = args.output or default_report
        report = generate_report(learnings_path, patterns_path, args.threshold, output)
        print(f"Report written: {output}")
        print()
        display_report(output)
        return 0

    elif args.command == "apply":
        report_path = args.report or default_report
        return apply_report(report_path, args.no_backup)

    elif args.command == "report":
        report_path = args.file or default_report
        return display_report(report_path)

    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    sys.exit(main())
