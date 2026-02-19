---
id: T-189
name: "Memory consolidation protocol — automated dedup and staleness pruning"
description: >
  Implement automated memory consolidation for project learnings/patterns. Google Context Engineering (T-120) identified this gap: AEF lacks automated deduplication, conflict resolution, and staleness pruning. Build a fw consolidate command that: (1) scans learnings.yaml for semantic duplicates, (2) detects stale/outdated learnings, (3) merges duplicates preserving the richest version, (4) prunes confirmed-stale entries, (5) generates a consolidation report. Must be file-based (D4), deterministic (D2), and safe (dry-run default).

status: work-completed
workflow_type: build
owner: claude-code
horizon: now
tags: []
related_tasks: []
created: 2026-02-19T09:07:11Z
last_update: 2026-02-19T09:12:23Z
date_finished: 2026-02-19T09:12:23Z
---

# T-189: Memory consolidation protocol — automated dedup and staleness pruning

## Context

T-120 inception (Google Context Engineering) identified this gap: AEF lacks automated deduplication, conflict resolution, and staleness pruning of learnings/patterns. With 58 learnings and growing, duplicates are confirmed (e.g., L-007/L-024, L-006/L-017, L-033/L-043). See `docs/reports/T-120-google-context-engineering-review.md`.

## Acceptance Criteria

- [x] `fw consolidate scan` analyzes learnings.yaml and detects duplicate clusters via text similarity
- [x] `fw consolidate scan` detects stale learnings (TBD application, superseded by later entries)
- [x] `fw consolidate scan` generates a consolidation report in `.context/working/consolidation-report.yaml`
- [x] `fw consolidate apply` merges duplicates and prunes stale entries with backup
- [x] Dry-run is default — `scan` never modifies source files
- [x] Patterns.yaml is also scanned for duplicates

## Verification

python3 -c "import yaml; yaml.safe_load(open('.context/project/learnings.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('.context/project/patterns.yaml'))"
fw consolidate scan 2>&1 | grep -q "duplicate"
test -f agents/context/consolidate.py

## Decisions

### 2026-02-19 — Duplicate detection algorithm
- **Chose:** Jaccard similarity on word tokens with dual-field comparison (primary field + combined fields), threshold 0.35
- **Why:** Deterministic (D2), no external dependencies (D4), catches confirmed duplicates (L-006/L-017, L-007/L-024) while avoiding false positives (L-002/L-038 at 0.105)
- **Rejected:** LLM-based comparison (non-deterministic), embedding similarity (requires external library), threshold 0.25 (too many false positives)

## Updates

### 2026-02-19T09:07:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-189-memory-consolidation-protocol--automated.md
- **Context:** Initial task creation

### 2026-02-19T09:12:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
