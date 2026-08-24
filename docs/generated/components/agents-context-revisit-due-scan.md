# revisit-due-scan

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/revisit-due-scan.sh`

## What It Does

revisit-due-scan.sh — Daily scan for ripe revisit_at deferrals (T-1452 / G-053)
Scans $PROJECT_ROOT/.tasks/active/*.md for frontmatter `revisit_at: <YYYY-MM-DD>`
entries whose date is <= today (UTC). Writes ripe matches to
.context/working/.revisits-due.txt — one line per task:
T-XXX fires YYYY-MM-DD: <name>
When no tasks are ripe the output file is removed entirely so downstream
readers (handover banner, Watchtower) can treat "file absent" and "file
empty" as the same signal — nothing to surface.
T-2865: SECOND, SEPARATE SIGNAL — .context/working/.revisits-undated.txt
The absent==empty contract above is correct for the *dated* population and was

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [revisit_signal_untracked](/docs/generated/tests-unit-revisit_signal_untracked) | called_by | TODO: describe what this component does |
| [revisit_signal_untracked](/docs/generated/tests-unit-revisit_signal_untracked) | tests_by | TODO: describe what this component does |
| [revisit_undated_signal](/docs/generated/tests-unit-revisit_undated_signal) | called_by | TODO: describe what this component does |
| [revisit_undated_signal](/docs/generated/tests-unit-revisit_undated_signal) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-revisit-due-scan.yaml`*
*Last verified: 2026-07-22*
