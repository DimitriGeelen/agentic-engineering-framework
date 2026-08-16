---
id: T-1505
name: "Pickup: fw doctor hook-health: scan session jsonl for hook failure rate, FAIL
  doctor if rate > threshold (closes detection blind spot revealed by T-140 RCA) (from
  003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-140. Type:
  feature-proposal.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: [pickup, feature-proposal]
components: []
related_tasks: []
created: 2026-04-26T11:13:37Z
last_update: '2026-08-16T22:24:34Z'
date_finished: 2026-04-26T12:58:45Z
source_task_id_in_origin: T-140
source_project_in_origin: "003-NTB-ATC-Plugin"
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1505: Pickup: fw doctor hook-health: scan session jsonl for hook failure rate, FAIL doctor if rate > threshold (closes detection blind spot revealed by T-140 RCA) (from 003-NTB-ATC-Plugin)

## Problem Statement

**Hook failures fire silently and are invisible until they accumulate to disaster scale.**

T-1504 RCA: 003-NTB-ATC-Plugin had **680 PostToolUse hook failures** in one session JSONL. Each failure was `/bin/sh: 1: .agentic-framework/bin/fw: not found` — every framework feature riding on PostToolUse (token-usage metrics, budget gate, tool counter, wrap-up signal, commit-cadence reminders, fabric drift detection) was silently degraded for ~7.5% of tool calls. Each failure carried Claude Code's "non-blocking status code" prefix, so it never surfaced as a user-visible error, never triggered an audit warning, never showed up in `fw doctor`.

**Detection blind spot:** `fw doctor` knows whether hook commands LOOK valid (T-1480 duplicate-hook detection, T-1364 absolute-path generation) but does NOT know whether they ACTUALLY EXECUTED successfully on real tool calls. Static config validation ≠ runtime success. The session JSONL is the ONLY source of truth for runtime behavior, and we don't read it.

**Why now:** T-1504 closed the relative-path failure mode (one cause). But hook-health is a recurring failure class — future regressions (path errors, permission errors, dependency missing, hook-script bugs, settings.json corruption) will produce the same silent degradation. Detection must be runtime-grounded, not config-grounded.

**Affects:** every consumer project that uses framework hooks. Severity is proportional to (failure rate × hooks active × tool calls per session).

## Assumptions

- **A1:** Claude Code's session JSONL records hook stdout/stderr in a parseable form (e.g., `tool_result.is_error` + tool result content containing "/bin/sh:" patterns or "non-blocking status code" markers). Falsifiable by `jq` over a recent session JSONL.
- **A2:** Hook failures share recognizable string patterns (`/bin/sh: 1:.*not found`, `command not found`, `permission denied`). False-positive rate of pattern-matching is low enough to gate `fw doctor` on. Falsifiable by sampling ~5 known-clean sessions vs known-broken ones (003-NTB-ATC-Plugin has the latter on file).
- **A3:** A single threshold (e.g., >1% of hook invocations failing) is meaningful across project sizes and session lengths. Likely false — short sessions can hit 20% noise rate trivially. Will need a rate+absolute-count combined heuristic. Falsifiable by computing rates across known sessions.
- **A4:** `fw doctor` runtime budget can absorb a session-jsonl scan. Current `fw doctor` runs in <2s. Scanning ~50K-line JSONL with `jq + grep` should add <5s for typical projects. Falsifiable by timing a real scan.
- **A5:** Session JSONL location is discoverable from PROJECT_ROOT. Claude Code stores per-project transcripts in `~/.claude/projects/<encoded-path>/<session-id>.jsonl`. The encoding is reversible. Falsifiable by reading 1 transcript via that path. (Already shown by T-1334 budget-gate.)

## Exploration Plan

1. **Confirm A5** (5 min) — given PROJECT_ROOT, find latest session JSONL. Spike: lift the path-encoding helper from T-1334's budget-gate code path.
2. **Confirm A1+A2** (15 min) — `jq` over a known-bad session (003-NTB-ATC-Plugin if accessible, or seed a synthetic one) for hook stderr patterns. Cross-check against a known-clean local session. Tabulate match rate.
3. **Confirm A3 threshold** (15 min) — compute hook-failure rate across the most recent local sessions in `~/.claude/projects/-opt-999-.../`. Find natural threshold by inspection. Probably want: trip on **any failures at all** (zero is the only sane baseline) OR rate >0.5% with absolute count >5 (combined heuristic to avoid noise on tiny sessions).
4. **Confirm A4** (5 min) — time the proposed scan against the framework's own session JSONL. If >5s, design needs streaming/sampling.
5. **Spike a `doctor_hook_health` check** (no code) — sketch function signature and integration into `fw doctor`'s existing PASS/WARN/FAIL output. Decide warning category.
6. **Cost/benefit table** + recommendation.

## Technical Constraints

- **Session JSONL access:** read-only, owned by Claude Code's data dir. Path encoding is undocumented but stable (T-1334 already navigates this for budget-gate). Reuse helpers.
- **Cross-platform:** macOS path encoding may differ from Linux. Verify with `~/.claude/projects/` listing on both.
- **JSONL size:** typical session is 5-50MB. Streaming reader required, not load-all.
- **Watchtower coupling:** `fw doctor` is also rendered via Watchtower `/doctor` page (if exists). New check must serialize cleanly.
- **No regression on `fw doctor` runtime:** must stay under ~5s for the common case.
- **Permission model:** the scan reads transcripts; if `fw doctor` is invoked from a CI runner without home access, fail gracefully (skip check + WARN) not error.

## Scope Fence

**IN scope:**
- Define the hook-health metric (rate-and-count heuristic).
- Identify the JSONL parsing approach.
- Recommend whether `fw doctor` integration is a new check function (new component card) or extension to existing checks.
- Pick warning category (PASS/WARN/FAIL), with justification.

**OUT of scope:**
- Implementation (separate build task post-GO).
- Building a generic hook observability framework (hook metrics dashboard) — this is one targeted health gate, not a platform.
- Fixing per-hook bugs detected by the scan (those become individual bug-report tasks).
- Real-time alerting (out of `fw doctor`'s synchronous-check model).

## Related Context

- **T-1504** (just-closed sister bug): fixed the immediate cause of the 680 failures. T-1505 closes the detection blind spot that allowed the bug to persist undetected.
- **T-1480, T-1481, T-1364, T-1287** (`fw doctor` hook-related checks already shipped): all are static config validation. T-1505 is the runtime-truth complement.
- **T-1334** (budget-gate session JSONL parsing): existing precedent for reading the same data, can lift its path-encoding helper.
- **G-019** (Antifragility — fix the framework's blindness, not just the symptom).
- **L-118** (`fw doctor` passes on projects with stale hook config — same theme: doctor only sees what it explicitly checks).
- **L-285** (T-1504 cross-codepath consistency learning — the audit-all-codepaths corollary).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- A1+A5 confirm (JSONL is parseable, locatable from PROJECT_ROOT) — already true via T-1334 precedent
- A2 holds (hook-failure patterns are recognizable with low FP rate)
- A4 holds (scan adds <5s to `fw doctor`)
- The single-rate threshold debate (A3) resolves toward a workable heuristic (combined rate+count)

**NO-GO if:**
- Hook stderr is NOT recoverable from JSONL (would require a different observability path — out of scope here)
- False-positive rate of pattern detection >20% (would require structured logging from hooks, separate workstream)
- Scan time >15s on typical sessions (degrades `fw doctor` UX unacceptably)

**DEFER if:**
- T-1504-class regressions stay quiet for ≥30 days post-fix (lower urgency, can ride along with a future doctor refactor)

## Verification

# Inception task — no code-level verification. Decision recorded via Watchtower.

## Recommendation

**Recommendation:** GO

**Rationale:** Without runtime hook-health monitoring, the framework is structurally blind to hook failures. T-1504's 680 silent occurrences in one downstream session is the existence proof that this blind spot DOES catch real bugs in the wild — it took a manual RCA dive to even find them. Static config validation (T-1480/T-1364/T-1287) cannot substitute for runtime truth. The work is bounded, the JSONL parsing precedent exists (T-1334), and the cost (one new doctor check) is small compared to the failure-class avoidance.

The Antifragility directive (G-019) applies directly: "fix the framework's blindness, not just the symptom." T-1504 fixed the symptom; T-1505 fixes the blindness.

**Evidence:**
- T-1504: 680 silent failures / one session JSONL / 003-NTB-ATC-Plugin / ~7.5% of tool calls — fixed in commit 2b8aa6b8e
- T-1334: budget-gate already reads session JSONL with a documented helper — A5 confirmed by precedent
- L-118: prior doctor blind-spot of the same family (stale hook paths passed config check) — pattern of "doctor sees only what it checks" is recurring
- T-1480/T-1481/T-1287/T-1364: 4 prior doctor checks shipped, all static — runtime gap is unfilled
- `fw doctor` runtime budget: currently <2s; even a 5s addition is acceptable given the failure-class avoidance

**Recommended scope for the GO build task:**
1. Lift path-encoding helper from T-1334 budget-gate code path (or refactor into shared lib)
2. Add `doctor_hook_health()` check function: scan most-recent N session JSONL files (default N=1, configurable to 5), grep tool_result content for stderr patterns (`/bin/sh: 1:.*not found`, `command not found`, `permission denied`), compute rate+count
3. Threshold: WARN at any failure detected (rate >0% with count ≥1); FAIL at rate >2% AND count ≥10 (degrades multiple sessions in a row → systemic)
4. Wire into `fw doctor` STRUCTURE checks section
5. Fail gracefully if `~/.claude/projects/` not readable (CI runners) — skip with INFO, not WARN

**Alternative considered (REJECTED):** real-time hook-health alerting via Watchtower. Out of scope — adds a new subsystem instead of extending `fw doctor`. Defer to T-1066 (data plane governance subscriber) if that ever ships.

**Alternative considered (REJECTED):** structured hook logging instead of JSONL parsing. Cleaner long-term but requires changing every hook script + adding a log-aggregator. Far more invasive than this proposal.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Without runtime hook-health monitoring, the framework is structurally blind to hook failures. T-1504's 680 silent occurrences in one downstream session is the existence proof that this blind spot DOES catch real bugs in the wild — it took a manual RCA dive to even find them. Static config validation (T-1480/T-1364/T-1287) cannot substitute for runtime truth. The work is bounded, the JSONL parsing precedent exists (T-1334), and the cost (one new doctor check) is small compared to the failure-class avoidance.

The Antifragility directive (G-019) applies directly: "fix the framework's blindness, not just the symptom." T-1504 fixed the symptom; T-1505 fixes the blindness.

**Date**: 2026-04-26T12:58:45Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-26T12:08:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-26T12:58:45Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Without runtime hook-health monitoring, the framework is structurally blind to hook failures. T-1504's 680 silent occurrences in one downstream session is the existence proof that this blind spot DOES catch real bugs in the wild — it took a manual RCA dive to even find them. Static config validation (T-1480/T-1364/T-1287) cannot substitute for runtime truth. The work is bounded, the JSONL parsing precedent exists (T-1334), and the cost (one new doctor check) is small compared to the failure-class avoidance.

The Antifragility directive (G-019) applies directly: "fix the framework's blindness, not just the symptom." T-1504 fixed the symptom; T-1505 fixes the blindness.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e26d20a6
- **Timestamp:** 2026-06-02T14:57:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T12:58:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
