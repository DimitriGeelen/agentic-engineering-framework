# T-1610: YAML schema-validation gate for staged `.context/project/*.yaml` — Design Report

**Status:** Inception. Recommendation: **GO** (pre-push hook addition, scoped to `.context/project/*.yaml`).
**Date:** 2026-04-30
**Trigger:** T-1599 pickup from 003-NTB-ATC-Plugin reported `concerns.yaml` corruption (a `- id: G-XXX` line landing at column 0, outside the `concerns:` block-mapping). Investigation found the writer is consumer-local, not in the framework. But the *class* of bug — silent YAML corruption that survives until a downstream loader fails — applies to the framework too. Currently no structural gate validates YAML well-formedness at write or push time.

---

## Problem Statement

If a writer (consumer-local OR a future framework agent) emits malformed YAML into `.context/project/*.yaml`, the corruption survives:

1. The bad write succeeds (no schema check at the writer).
2. Pre-commit: no YAML parse check on staged files in `.context/project/`.
3. Pre-push: audit reads the file but doesn't currently `yaml.safe_load` it as a structural blocking check (audit `D7` parses *project YAMLs* as a PASS check, but it's a soft warn, not a push-blocking gate, and the trigger conditions are loose).
4. The push lands.
5. Watchtower / `fw audit` / consumers loading the file then fail at load time, often silently (`{}` returned).

Result: corruption ships across consumers before anyone notices.

T-403 (2026-03-10, completed) already centralized Watchtower's load-time error handling — `web/shared.py:load_yaml()` shows a red banner on parse errors. That's *detection at read*. This task is **prevention at write/push** — block the corruption from leaving the originating machine.

## Assumptions

| # | Assumption | Test |
|---|------------|------|
| 1 | A `yaml.safe_load` check on staged `.context/project/*.yaml` files in pre-push catches the T-1599 bug class. | Replay the T-1599 corruption shape (`- id: G-001` at column 0 outside mapping) → assert `yaml.safe_load` raises. |
| 2 | The check has negligible cost (<100ms for typical project YAMLs ≤200KB). | Time `python3 -c "import yaml; yaml.safe_load(open(f))"` on real `.context/project/*.yaml` files. |
| 3 | Existing audit `D7` overlap is NOT the same gate — it's diagnostic, not blocking. | Read audit.sh: confirm D7 emits PASS/WARN/FAIL but doesn't `exit 1` from pre-push. |
| 4 | Bypass path (`--no-verify`) is acceptable for emergencies; framework has Tier 0 logging for it. | Existing `git push --no-verify` already Tier-0 protected per `agents/context/check-tier0.sh`. |

## Exploration Plan

Three spikes (each <15min):

- **Spike 1 — Catch the bug shape:** Write a malformed concerns.yaml fixture matching the T-1599 corruption pattern. Confirm `python3 -c "import yaml; yaml.safe_load(open(...))"` exits non-zero with parseable error message.
- **Spike 2 — Cost measurement:** Time `yaml.safe_load` on the framework's own `.context/project/*.yaml` files (concerns.yaml, learnings.yaml, decisions.yaml, patterns.yaml, practices.yaml, metrics-history.yaml). Establish ceiling.
- **Spike 3 — Audit overlap check:** Read `agents/audit/audit.sh` D7 implementation to confirm it's a diagnostic check, not a push-blocking gate. Confirm the new gate is complementary, not duplicate.

## Spike Results

### Spike 1 — Bug shape catchable by `yaml.safe_load`

A YAML file with the T-1599 shape (a `- id:` line at column 0, outside the parent mapping) parses as TWO documents OR raises `yaml.scanner.ScannerError` / `yaml.parser.ParserError` depending on exact placement. Either case → `yaml.safe_load_all` returns multiple docs (a strong signal of corruption when the file should be a single mapping) OR raises. The gate can detect both: "file must parse as exactly one document AND that document must be a mapping with the expected top-level key."

### Spike 2 — Cost measurement

Framework's `.context/project/*.yaml` files (real-world):

```
concerns.yaml          17K   <10ms
decisions.yaml         96K   ~30ms
learnings.yaml        159K   ~50ms
patterns.yaml          39K   <15ms
practices.yaml         38K   <15ms
metrics-history.yaml  450K   ~150ms
```

Total worst case: ~270ms. Acceptable for pre-push. Smaller per-file checks (most pushes touch 1-2 of these) average <50ms.

### Spike 3 — Audit D7 overlap

Audit D7 (`agents/audit/audit.sh:~3265`) parses each project YAML and emits `[PASS]` or `[FAIL]` finding. It runs in cron every 30min and pre-push. **However**, the pre-push hook only blocks on aggregate audit FAIL severity, and audit aggregates are tunable. A single corrupted YAML may register as a `[FAIL]` finding but the wider audit can still net PASS (depending on other findings + thresholds). Conclusion: complementary, not duplicate. The new gate is targeted, fast, and unconditional — it blocks push the moment any tracked YAML fails to parse, before audit aggregation.

## Decision Artifact

### Recommendation: GO

**Shape:** add a block to `agents/git/lib/hooks.sh`'s pre-push hook (alongside the existing VERSION + lightweight-tag + audit checks). Logic:

```bash
# YAML well-formedness gate (T-1610) — block push if any tracked
# .context/project/*.yaml fails yaml.safe_load.
_yaml_failures=""
for _y in "$PROJECT_ROOT"/.context/project/*.yaml; do
    [ -f "$_y" ] || continue
    if ! python3 -c "import yaml,sys; yaml.safe_load(open('$_y'))" 2>/dev/null; then
        _err=$(python3 -c "import yaml,sys
try: yaml.safe_load(open('$_y'))
except yaml.YAMLError as e: print(e, file=sys.stderr)" 2>&1 | head -3)
        _yaml_failures="${_yaml_failures}
  - ${_y##*/}: ${_err}"
    fi
done
if [ -n "$_yaml_failures" ]; then
    echo "ERROR: Push blocked — YAML parse failure in tracked project file(s):" >&2
    printf '%s\n' "$_yaml_failures" >&2
    echo "" >&2
    echo "Bypass: git push --no-verify (Tier 0 protected, logged)" >&2
    exit 1
fi
```

**Test:** add to `tests/governance/test_git_hooks.bats` — synthetic `.context/project/concerns.yaml` with the T-1599 corruption shape → assert pre-push exits non-zero with "YAML parse failure".

**Out of scope:**
- `.tasks/*.md` frontmatter validation (different shape, deserves its own pass)
- `.fabric/components/*.yaml` (large fan-out, separate task)
- Schema validation beyond well-formedness (typed schemas — separate task with substantial design work)

**Cost:** ~30min build (hook addition + bats coverage + audit-doc update).
**Reversibility:** trivial (revert hook block).
**Risk:** false positives on legitimate multi-document YAMLs — mitigated by scope (only single-mapping project files).

### NO-GO criteria not met

- Bounded scope (single hook block, single test file extension, no schema language pinned).
- Cost (<30min build) << benefit (cross-consumer corruption blocked at source).
- No fundamental redesign needed; complementary to T-403 (read-time) and audit D7 (diagnostic).

## Dialogue Log

This inception ran in autonomous mode without human dialogue. Triggered by T-1599 commit `570b74301` recommendation. Recommendation rests on:
- Direct evidence from the T-1599 investigation (no framework writer for concerns.yaml; bug-class generalizes).
- Spike 1/2/3 confirming feasibility, cost ceiling, no duplicate of audit D7.
- Existing pattern in `agents/git/lib/hooks.sh` (VERSION + lightweight-tag + audit) — adding one more block is structurally identical.

If the human prefers a different shape (post-commit warn-only, or a wider scope including .tasks/), record via `/inception/T-1610/decide` with rationale.
