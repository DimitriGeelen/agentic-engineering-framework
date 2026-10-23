# branch-hygiene

> lib/branch-hygiene.sh — T-100143 (C2 of T-100139 branch/worktree lifecycle GO)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/branch-hygiene.sh`

## What It Does

lib/branch-hygiene.sh — T-100143 (C2 of T-100139 branch/worktree lifecycle GO)
WARN-only branch hygiene scan. Prints one finding per line to stdout and
prints NOTHING when the repo is tidy — callers (fw doctor) wrap findings in
their own WARN formatting and count lines. Always exits 0: this is an
advisory rail, never a gate.
Judged against TARGET = the DEV branch — `origin/$FW_DEV_BRANCH` (default
`bleeding-edge`) when present, then its local ref, and only then origin/master
or master. T-3188. Under the release train (CLAUDE.md §Release-Train Branch
Model) master lags deliberately, so judging landings against it would report
every branch already landed on bleeding-edge as unlanded; the master legs

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [integrate](/docs/generated/lib-integrate) | called_by | fw integrate — Layer 2 serialized-integration preflight (T-2399, T-2397 slice 1). |
| [t3187_branch_identity_guard](/docs/generated/tests-unit-t3187_branch_identity_guard) | tests_by | T-3187: the branch guard must assert IDENTITY, not reconcilability. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [ewcr-arc0-writeset-scoped-coverage](/docs/generated/tools-ewcr-arc0-writeset-scoped-coverage) | called_by | EWCR Arc 0 — write-set-SCOPED fabric coverage (T-3401, EWCR-ARC0-ATTEST-832 Round 1). |

---
*Auto-generated from Component Fabric. Card: `lib-branch-hygiene.yaml`*
*Last verified: 2026-07-07*
