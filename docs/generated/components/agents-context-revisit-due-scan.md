# revisit-due-scan

> revisit-due-scan.sh — Daily scan for ripe revisit_at deferrals (T-1452 / G-053)

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
| [revisit_signal_untracked](/docs/generated/tests-unit-revisit_signal_untracked) | called_by | T-2866 — the revisit signal files must never be tracked by git. |
| [revisit_signal_untracked](/docs/generated/tests-unit-revisit_signal_untracked) | tests_by | T-2866 — the revisit signal files must never be tracked by git. |
| [revisit_undated_signal](/docs/generated/tests-unit-revisit_undated_signal) | called_by | T-2865 — DEFER decisions carrying no revisit date must be surfaced, separately. |
| [revisit_undated_signal](/docs/generated/tests-unit-revisit_undated_signal) | tests_by | T-2865 — DEFER decisions carrying no revisit date must be surfaced, separately. |

---
*Auto-generated from Component Fabric. Card: `agents-context-revisit-due-scan.yaml`*
*Last verified: 2026-07-22*
