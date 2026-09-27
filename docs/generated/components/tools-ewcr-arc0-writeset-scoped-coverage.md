# ewcr-arc0-writeset-scoped-coverage

> EWCR Arc 0 — write-set-SCOPED fabric coverage (T-3401, EWCR-ARC0-ATTEST-832 Round 1).

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/ewcr-arc0-writeset-scoped-coverage.py`

## What It Does

Verbatim from docs/research/executable-workflow/arc0-write-set.md, PLUS
one correction: `agents/orchestrator/` (832 @1601, EWCR-ARC0-ATTEST-832
Round 2) — the write-set-document's row 5 names only `lib/orchestrator`,
which matches zero files on disk, so the CORE measurement omitted the
runner/ledger/actions surface entirely (an empty-population-can't-fail

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [branch-hygiene](/docs/generated/lib-branch-hygiene) | calls | lib/branch-hygiene.sh — T-100143 (C2 of T-100139 branch/worktree lifecycle GO) |

---
*Auto-generated from Component Fabric. Card: `tools-ewcr-arc0-writeset-scoped-coverage.yaml`*
*Last verified: 2026-09-21*
