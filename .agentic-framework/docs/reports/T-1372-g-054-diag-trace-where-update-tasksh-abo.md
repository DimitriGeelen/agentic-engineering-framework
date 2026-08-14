# T-1372 — G-054 diag: trace where update-task.sh aborts silently

> **Inception research artifact** (backfilled by T-2515 from the `T-1372` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1372-g-054-diag-trace-where-update-tasksh-abo.md`. **Decision recorded: GO.**

## Context

Diagnostic inception — triggered by repeated G-054 reproduction during T-1370/T-1371 close. T-1371 landed always-on instrumentation at update-task.sh:845-878 that logs every episodic-gen invocation to `.context/working/.last-episodic-gen.log`. For T-1371's own close, the log was NOT written — the Episodic block never executed (output stopped at "Focus cleared"). Sandbox reproduction with similar task profile (T-9999) runs cleanly. Trigger appears tied to real git history (T-1371 has a matching commit; T-9999 had none). Hypothesis: the auto-populate-components block (lines 749-795) or auto-capture-decisions block (lines 797-837) silently aborts under `set -e` for tasks with matching commits.

## Exploration Findings

- **Spike 1 (minimal task, no commits):** auto-gen runs ✓
- **Spike 2 (full profile: ACs + Verification + Decisions template, no matching commits):** auto-gen runs ✓
- **Spike 3 (real task T-1371 with 1 matching commit touching 3 files):** auto-gen FAILED silently ✗

## Recommendation

**Recommendation:** GO — close as superseded. T-1374 used this task's instrumentation to find and fix the root cause.

**Rationale:** The Human AC ("next real task close captures `.last-episodic-gen.log` — use for live diagnosis") was satisfied during T-1374's work. The instrumentation revealed the abort point via `bash -x` tracing; root cause was grep/git pipelines inside `$(...)` under `set -euo pipefail` aborting via command-substitution assignment before the Episodic block ran. Fix landed as `|| true` on update-task.sh:769,775. G-054 flipped to `mitigated`. L-236 captured the pattern. Regression test pins it.

**Evidence:**
- Root cause found: `set -euo pipefail` + grep-no-match in `$(...)` assignments aborts script via EXIT trap before reaching instrumented block
- Fix: commit 65a8a76e (update-task.sh:769,771-772 + 775-779) — `|| true` on ALL_PATHS git loop and comp_id grep pipeline
- Regression test: tests/unit/update_task_components_lookup.bats (sanity-inverse verified)
- Concern G-054: flipped to `mitigated` in `.context/project/concerns.yaml`
- Learning L-236: captured in `.context/project/learnings.yaml` — "set -euo pipefail silently aborts via command-substitution assignments"
- T-1374's own close: log captured, exit 0, episodic generated — the AC step executed successfully on real task close

## Decision

**Decision**: GO (close as superseded)

**Rationale**: T-1374 used the instrumentation landed by T-1371 (this task's sibling) to find and fix the root cause. Human AC "Next real task close captures .last-episodic-gen.log" was satisfied via T-1374's work — the log was written, exit 0, episodic generated. G-054 flipped to `mitigated`; L-236 captures the pattern.

**Date**: 2026-04-21T20:37:23Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d9241844
- **Timestamp:** 2026-06-02T14:57:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#1 (Human)
