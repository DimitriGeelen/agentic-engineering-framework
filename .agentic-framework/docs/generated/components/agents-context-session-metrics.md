# session-metrics

> Extract per-session quality metrics (CPT, error rate, edit bursts) from JSONL transcript

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/session-metrics.sh`

## What It Does

Session Quality Metrics — JSONL transcript analyzer (T-831)
Single-pass analysis of current session's JSONL transcript to extract
quality metrics for handover frontmatter and /timeline display.
Usage:
agents/context/session-metrics.sh          # Analyze current session
agents/context/session-metrics.sh <path>   # Analyze specific JSONL
Output: .context/working/.session-metrics.yaml
Metrics extracted (P0 from T-830 Agent B design):
- commits_per_turn: Productive output density
- first_commit_turn: Session startup efficiency

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [checkpoint](/docs/generated/checkpoint) | calls | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [init](/docs/generated/agents-context-lib-init) | reads | Context Agent - init command |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |

## Related

### Tasks
- T-831: Session quality metrics — session-metrics.sh JSONL analyzer + handover integration
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-850: Fix session metrics — per-session deltas instead of cumulative transcript analysis
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes

---
*Auto-generated from Component Fabric. Card: `agents-context-session-metrics.yaml`*
*Last verified: 2026-04-04*
