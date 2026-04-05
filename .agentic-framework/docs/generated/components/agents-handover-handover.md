# handover

> Handover Agent - Mechanical Operations

**Type:** script | **Subsystem:** handover | **Location:** `agents/handover/handover.sh`

## What It Does

Handover Agent - Mechanical Operations
Creates handover documents for session continuity

### Framework Reference

**Location:** `agents/handover/`

**When to use:** MANDATORY at end of every session.

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `agents/task-create/create-task.sh` | calls |
| `C-008` | calls |
| `agents/git/git.sh` | calls |
| `lib/paths.sh` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `agents/context/pre-compact.sh` | called_by |
| `bin/fw` | called_by |
| `C-008` | called_by |
| `agents/onboarding-test/test-onboarding.sh` | called_by |

## Documentation

- [Deep Dive: Context Budget Management](docs/articles/deep-dives/03-context-budget.md) (deep-dive)

## Related

### Tasks
- T-820: Fix TermLink dispatch preamble — workers write to target files
- T-829: Input/output token breakdown — enrich handover frontmatter and timeline display
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-850: Fix session metrics — per-session deltas instead of cumulative transcript analysis
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes

---
*Auto-generated from Component Fabric. Card: `agents-handover-handover.yaml`*
*Last verified: 2026-02-20*
