# arc

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/arc.sh`

## What It Does

lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661)
Arcs are first-class workspaces grouping tasks by theme. An arc has
a slug id (`orchestrator-rethink`), a name, an optional anchor task,
and a list of constituent tasks. Arcs surface via:
- `.context/arcs/<id>.yaml` registry
- `.context/working/arc-focus.yaml` (single-arc focus, single-task analog)
- `arc:<id>` tag namespace (canonical; legacy `from-T-XXXX` mapped on migrate)
- handover.sh `## Current Arc` section
- Watchtower landing-page section + `/tasks?arc=<id>` filter chip
Verbs:

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
