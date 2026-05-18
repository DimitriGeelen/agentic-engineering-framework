# arc

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/arc.sh`

## What It Does

lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848)
Arcs are first-class workspaces grouping tasks by theme. Two identities:
• slug  — human-readable filename stem (e.g., `orchestrator-rethink`).
Used in URLs, tags (arc:<slug>), and discussion. Stable but
not immutable — a slug may be renamed (rare; never auto).
• arc-NNN — immutable sequential numeric ID (e.g., `arc-001`) written
into the YAML's `id:` field at creation time. Never renumbered,
never reused, never deleted (status flips, file stays).
D-Immutability axiom (T-1846 inception §11.3, captured here so future
changes find it):

### Framework Reference

Enforced structurally. `fw arc create` requires `--headline-mechanic "<who> <does what> <observes what user-visible result>"` and rejects substrate-only phrasing. `fw arc close` requires `--demo <path|url|none>` — a wire-level artefact (meta.json, stream-json, screencast, live URL) traceable to the arc, or `none` with a `--justification` logged to `.context/audits/arc-bypass.jsonl`. The gates fire before any closure narrative; substrate-vs-deliverable conflation cannot bypass them.

*(truncated — see CLAUDE.md for full section)*

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/task-create/update-task.sh` | calls |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `tests/unit/test_arc_system.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-arc.yaml`*
*Last verified: 2026-05-01*
