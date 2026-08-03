# branch-hygiene

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/branch-hygiene.sh`

## What It Does

lib/branch-hygiene.sh — T-100143 (C2 of T-100139 branch/worktree lifecycle GO)
WARN-only branch hygiene scan. Prints one finding per line to stdout and
prints NOTHING when the repo is tidy — callers (fw doctor) wrap findings in
their own WARN formatting and count lines. Always exits 0: this is an
advisory rail, never a gate.
Judged against TARGET = origin/master when present, else master. Repos with
no master lineage produce no findings (nothing to judge against).
Finding classes (one token-prefixed line each):
merged-undeleted <branch>                    local branch tip contained in TARGET
behind-threshold <branch> behind=<n> (threshold <t>)

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-branch-hygiene.yaml`*
*Last verified: 2026-07-07*
