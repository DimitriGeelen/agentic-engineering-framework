# T-1319: fw fabric drift/scan miss recursive glob matches

**Source:** termlink T-1130 pickup (P-037)
**Status:** GO — build sibling T-1320
**Date:** 2026-04-18

## Bug

Two framework paths inspect file membership against `.fabric/watch-patterns.yaml` glob entries:

| Path | Implementation | Recursive `**` behavior |
|------|---------------|-------------------------|
| `fw audit` | Python `glob.glob(pattern, recursive=True)` | Matches files under nested dirs |
| `fw fabric drift` | bash `for file in $glob_pattern` | **Single-level only** (default bash) |
| `fw fabric scan` | bash `for file in $glob_pattern` | **Single-level only** (default bash) |

Result: audit warns about an unregistered file under a recursive glob, the operator runs `fw fabric scan` (as audit suggests), nothing changes, the warning persists. Loop.

## Root Cause

Bash defaults treat `**` as `*` unless `shopt -s globstar` is enabled in scope. The two affected functions don't enable it:

- `agents/fabric/lib/drift.sh:26` — `for file in $glob_pattern`
- `agents/fabric/lib/register.sh:292` — `for file in $glob_pattern`

Termlink reproduced the divergence directly:

```
$ bash -c 'for f in crates/*/src/**/*.rs; do echo $f; done' | wc -l
14
$ bash -c 'shopt -s globstar; for f in crates/*/src/**/*.rs; do echo $f; done' | wc -l
68
```

## Fix

Add at the top of each affected function:

```bash
shopt -s globstar nullglob 2>/dev/null || true
```

Both options are opt-in per-shell:
- `globstar` makes `**` match nested directories (the actual fix).
- `nullglob` makes unmatched globs expand to nothing instead of the literal pattern (defensive — the loop body already uses `[ -f "$file" ] || continue`, so this is a strict no-op improvement).
- `2>/dev/null || true` keeps the line POSIX-safe on shells without `shopt`.

## Why GO

- Concrete bug with reproducible repro from termlink
- Fix is mechanical, scoped, and matches Python audit's behavior
- No conflicting tests today
- Risk near zero — opt-in shell options, additive behavior

## Build Plan

Build task **T-1320** ships:
1. `shopt -s globstar nullglob` in `do_drift` and `do_scan`
2. Bats regression that creates a temp project with a recursive glob pattern and a nested file, asserts `do_scan` finds it
3. (Optional) audit other bash glob loops in `agents/` for the same issue — done if ≤2 sites, else separate task

## Decision Trail

- Source pickup: `.context/pickup/inbox/P-037-bug-report.yaml` (will move to processed/)
- Inception: `.tasks/active/T-1319-pickup-fw-fabric-drift-and-scan-miss-rec.md`
- Build sibling: T-1320
- Recommendation: GO
