# T-2159 — horizon terminal-state fix — completion→past transition + invariant guard

> **Inception research artifact** (backfilled by T-2515 from the `T-2159` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-2159-horizon-terminal-state-fix--completionpa.md`. **Decision recorded: DEFER.**

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Recommendation

**Recommendation:** DEFER

**Rationale:**

Horizon axis (now/next/later) has a one-way coupling: tasks enter horizon: now when work starts but nothing moves them off when work completes. now silently accumulates terminal tasks. Fix direction is right (a past representation); exact mechanism is the open question. Step 0 verification required before design: confirm actual horizon storage / allowed values / current transition logic / read surfaces. Four open questions: (Q1) representation shape — clear / derived-past / settable-past with invariant protection; (Q2) which lifecycle statuses count as terminal; (Q3) backfill polluted data or grandfather; (Q4) read-surface filter implications. Per prompt: standalone task-system change, NOT entangled with T-2158 (continuous-run) or T-2157 (value-drivers).

**Evidence:**

## Decision

**Decision**: GO

**Rationale**: Recommendation: DEFER

Rationale:

Horizon axis (now/next/later) has a one-way coupling: tasks enter horizon: now when work starts but nothing moves them off when work completes. now silently accumulates terminal tasks. Fix direction is right (a past representation); exact mechanism is the open question. Step 0 verification required before design: confirm actual horizon storage / allowed values / current transition logic / read surfaces. Four open questions: (Q1) representation shape — clear / derived-past / settable-past with invariant protection; (Q2) which lifecycle statuses count as terminal; (Q3) backfill polluted data or grandfather; (Q4) read-surface filter implications. Per prompt: standalone task-system change, NOT entangled with T-2158 (continuous-run) or T-2157 (value-drivers).

Evidence:

**Date**: 2026-06-01T09:51:33Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9bb9b03f
- **Timestamp:** 2026-06-02T15:01:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-06-01T09:51:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
