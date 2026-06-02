---
id: T-2057
name: "L-387 SIGPIPE detector — static scan of ## Verification blocks for pipefail-fatal
  grep -q patterns"
description: >
  6 captures of L-387 (pipefail+SIGPIPE) in session S-2026-0526..-0527: T-1716, T-1838,
  T-1862, T-1863, T-2008, T-1701, T-1707. Each manifests as 'cmd | grep -q PATTERN'
  or 'cmd | grep X | wc -l | grep -q' inside ## Verification — grep matches first
  hit, closes stdin, upstream cmd gets SIGPIPE, pipefail returns 141, verification
  gate refuses close. Each fix was site-local. Class warrants a structural detector:
  reviewer/audit pattern scan of all .tasks/active/*.md and .tasks/completed/*.md
  for ## Verification blocks containing the anti-pattern. Could ship as (a) a fw reviewer
  pattern, (b) an audit check, (c) a PreToolUse hook on Edit of .tasks/*.md, or (d)
  update-task.sh lint at --status started-work time. Open question: which surface
  gives the right ergonomics? Decision: GO/NO-GO + which surface.

status: work-completed
workflow_type: inception
owner: claude
horizon: null
tags: [L-387, reviewer, structural-detector, level-D]
components: [bin/fw, tests/unit/test_doctor_scope_tags.bats, tests/unit/test_work_on_completed_task.bats]
related_tasks: []
created: 2026-05-27T05:20:09Z
last_update: 2026-05-27T23:46:11Z
date_finished: 2026-05-27T23:46:11Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
cost_estimate_proposed:
  - ts: '2026-05-27T05:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-27T05:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2057: L-387 SIGPIPE detector — static scan of ## Verification blocks for pipefail-fatal grep -q patterns

## Problem Statement

L-387 (`cmd | grep -q PATTERN` or `cmd | grep X | wc -l | grep -q "^N$"` under `set -eo pipefail`) has been captured **7 times** in two consecutive sessions (S-2026-0526..-0527):
T-1716, T-1838, T-1862, T-1863, T-2008, T-1701, T-1707. Each was site-local: edit the verification block, swap to capture-to-tempfile, retry close.

The class is fully detectable statically: a regex scan over `## Verification` blocks in every task file. The framework has no detector for it. Each new occurrence costs one close cycle + one fix cycle. At the observed rate (~3-4 per active autonomous session), this is meaningful drag.

**Per L-364 (cron) / L-417 (stale-slice) precedent:** when a failure class repeats ≥3× and is statically detectable, it warrants a structural detector. 7× crosses the bar by a wide margin.

## Assumptions

- A1: A regex/AST pattern matching the L-387 anti-patterns in `## Verification` blocks has ≥95% precision (low false-positive rate on legitimate `grep -q` uses where the upstream cmd is short / non-streaming).
- A2: Authors will accept the detector — the fix (capture-to-tempfile) is ~1 line and well-understood.
- A3: A reviewer-pattern surface (`fw reviewer T-XXX`) is the right home, because the existing reviewer agent already scans `## Verification` for other anti-patterns.

## Exploration Plan

1. **Spike (30 min):** grep all `.tasks/{active,completed}/*.md` for the literal anti-patterns:
   - `| grep -q [^|]*$` (terminal `grep -q` in a pipe)
   - `| grep [^|]* | wc -l | grep -q` (count-then-match)
   - measure: how many existing files match? How many of those are genuine L-387 risks vs benign uses?
2. **Decide surface:** (a) `fw reviewer` pattern (warn at scan time); (b) `fw audit` check (daily WARN); (c) PreToolUse hook on Write/Edit of `.tasks/*.md` (block); (d) `update-task.sh` lint at `--status started-work` time (block early).
3. **Cost-precision tradeoff:** a hook blocks early but is noisy; a reviewer pattern is non-blocking but author-discoverable; an audit catches the long tail.

## Technical Constraints

- Detector must distinguish `cmd | grep -q PATTERN` (RISK — upstream cmd can SIGPIPE) from `echo "$var" | grep -q PATTERN` (SAFE — echo is instant and short).
- Heuristic: flag when upstream cmd is `bin/fw doctor`, `bin/fw audit`, `bats`, or any multi-line command (e.g. `for ... done`).
- Whitelist: `printf`, `echo`, single-call `cat <file>`.

## Scope Fence

**IN:** detector design + surface decision + a 1-page report mapping each of the 7 prior captures to what the detector would have flagged.
**OUT:** building the detector itself — that's a downstream build slice contingent on this inception's GO.

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

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:** 7 captures of L-387 in two consecutive autonomous sessions
(S-2026-0526..-0527). Class is statically detectable: refined heuristic
distinguishes ~15 true positives from ~26 safe `out=$(cmd); echo "$out"
| grep -q` cases in the 44-line risky candidate corpus. Detector cost
bounded: reviewer pattern + `update-task.sh started-work` advisory is
<1 day of build work. ≥3 statically-detectable repeats threshold (per
L-364 / L-417) crossed by a wide margin.

**Evidence:** See full spike report at
[`docs/reports/T-2057-l-387-detector-spike.md`](../../docs/reports/T-2057-l-387-detector-spike.md)
— anti-pattern signature, mechanism explanation, corpus scan, refined
heuristic, 4 surface candidates with pro/con, build-slice scope.

**Build slice (post-GO):** reviewer pattern `l387-sigpipe-risk` +
`update-task.sh` started-work advisory (warn only, not block) + bats
coverage against the 15 historical positives.

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

**Rationale**: Recommendation: GO

Rationale: 7 captures of L-387 in two consecutive autonomous sessions
(S-2026-0526..-0527). Class is statically detectable: refined heuristic
distinguishes ~15 true positives from ~26 safe `out=$(cmd); echo "$out"
| grep -q` cases in the 44-line risky candidate corpus. Detector cost
bounded: reviewer pattern + `update-task.sh started-work` advisory is
<1 day of build work. ≥3 statically-detectable repeats threshold (per
L-364 / L-417) crossed by a wide margin.

Evidence: See full spike report at
[`docs/reports/T-2057-l-387-detector-spike.md`](../../docs/reports/T-2057-l-387-detector-spike.md)
— anti-pattern signature, mechanism explanation, corpus scan, refined
heuristic, 4 surface candidates with pro/con, build-slice scope.

Build slice (post-GO): reviewer pattern `l387-sigpipe-risk` +
`update-task.sh` started-work advisory (warn only, not block) + bats
coverage against the 15 historical positives.

**Date**: 2026-05-27T23:46:11Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-27T23:46:11Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: 7 captures of L-387 in two consecutive autonomous sessions
(S-2026-0526..-0527). Class is statically detectable: refined heuristic
distinguishes ~15 true positives from ~26 safe `out=$(cmd); echo "$out"
| grep -q` cases in the 44-line risky candidate corpus. Detector cost
bounded: reviewer pattern + `update-task.sh started-work` advisory is
<1 day of build work. ≥3 statically-detectable repeats threshold (per
L-364 / L-417) crossed by a wide margin.

Evidence: See full spike report at
[`docs/reports/T-2057-l-387-detector-spike.md`](../../docs/reports/T-2057-l-387-detector-spike.md)
— anti-pattern signature, mechanism explanation, corpus scan, refined
heuristic, 4 surface candidates with pro/con, build-slice scope.

Build slice (post-GO): reviewer pattern `l387-sigpipe-risk` +
`update-task.sh` started-work advisory (warn only, not block) + bats
coverage against the 15 historical positives.

### 2026-05-27T23:46:11Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5b6089c4
- **Timestamp:** 2026-06-02T15:00:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-27T23:46:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
