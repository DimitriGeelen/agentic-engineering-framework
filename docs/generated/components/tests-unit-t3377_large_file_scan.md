# t3377_large_file_scan

> T-3377 — large-file scan_tree: behaviour pinned against a FIXTURE repo.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3377_large_file_scan.bats`

## What It Does

T-3377 — large-file scan_tree: behaviour pinned against a FIXTURE repo.
scan_tree was rewritten to size-filter in bulk (one batched `stat` pass + an
awk threshold cut) instead of forking `grep` and `stat` once per tracked file.
At 17,270 tracked files the old shape cost ~35-50k process spawns, measured at
user 19s / sys 49s and unfinished at a 60s timeout — which is why `fw doctor`,
whose large-file check calls this inline, returned 124 instead of a verdict.
The rewrite is supposed to be performance-only, so what needs pinning is that
the REPORTING RULES did not move: which paths are named, at which threshold,
in which order, and that the allowlist still exempts from BOTH levels.
Everything here runs against a throwaway git repo built in setup(), with the

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [large-file-scan](/docs/generated/agents-git-lib-large-file-scan) | tests | agents/git/lib/large-file-scan.sh — Large-file gate for the pre-commit hook (T-1845). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3377_large_file_scan.yaml`*
*Last verified: 2026-09-16*
