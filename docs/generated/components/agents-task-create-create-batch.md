# create-batch

> fw task create-batch — create many tasks in one call (T-5221, slice 2 of inception T-5212).

**Type:** script | **Subsystem:** task-management | **Location:** `agents/task-create/create-batch.sh`

## What It Does

fw task create-batch — create many tasks in one call (T-5221, slice 2 of inception T-5212).
Design: docs/reports/T-5212-batch-task-creation.md (1409's prototype, 2.6 s per unit).
fw task create-batch --spec F.jsonl --purpose <text> [--dry-run]
F.jsonl holds one JSON object per line (blank lines and lines starting with # are skipped):
{"name": "...", "description": "...", "type": "build", "owner": "agent",
"horizon": "next", "tags": ["a", "b"] | "a,b", "related": [...] | "T-1,T-2",
"arc_id": "<arc slug or arc-NNN>"}
name, description, type and owner are required; horizon defaults to now.
Order, and why:
1. Every entry is checked by the rules create-task uses (lib/task-create-rules.sh), plus

---
*Auto-generated from Component Fabric. Card: `agents-task-create-create-batch.yaml`*
*Last verified: 2026-11-18*
