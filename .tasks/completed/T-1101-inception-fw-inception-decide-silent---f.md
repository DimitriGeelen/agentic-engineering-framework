---
id: T-1101
name: "Inception: fw inception decide silent --force bypass — RCA + remediation path
  (G-032 CRITICAL)"
description: >
  Inception task — investigate the CRITICAL bug at lib/inception.sh:303 where fw inception
  decide silently passes --force to update-task.sh, bypassing P-010 (agent AC gate),
  P-011 (verification gate), AND the Human Task Completion Rule. Trigger: /opt/termlink
  T-909 transcript 2026-04-11 — fw inception decide T-909 go printed 'Completing human-owned
  task (--force bypass)' and '3/3 agent AC unchecked (--force bypass)' with the user
  never having passed --force. Comment at lib/inception.sh:299 cites T-637 with the
  premise that inception decide is Tier-0-gated, which is FALSE. Investigate: (1)
  full T-637 history — what problem was it solving and is there a non-bypass solution?
  (2) the actual call sites of inception decide and whether removing --force breaks
  anything legitimate; (3) whether splitting decision-recording from task-completion
  is feasible (decide writes rationale, completion is a separate user action); (4)
  backwards compat — what existing inceptions would suddenly fail their AC gate if
  --force is removed; (5) recommend GO/NO-GO/DEFER with concrete remediation path.
  Origin: G-032.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: [T-1093, G-032]
created: 2026-04-11T12:37:23Z
last_update: '2026-08-16T22:24:22Z'
date_finished: 2026-04-12T10:05:26Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
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
  - ts: '2026-08-16T22:24:22Z'
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

# T-1101: Inception: fw inception decide silent --force bypass — RCA + remediation path (G-032 CRITICAL)

## Problem Statement

`fw inception decide T-XXX go` (or `no-go`) calls `update-task.sh --status work-completed --force` internally at `lib/inception.sh:303`. The user does not pass `--force`. The framework adds it silently. Result: every inception that ends in go/no-go bypasses three structural gates simultaneously:

1. **P-010** — agent acceptance criteria checkbox gate
2. **P-011** — verification command gate (the `## Verification` section)
3. **Human Task Completion Rule** — human-owned tasks should never be auto-completed

The justification at `lib/inception.sh:299` reads: *"--force bypasses sovereignty gate (R-033) because inception decide itself required Tier 0 approval — human authority was already exercised (T-637)"*. This premise is **factually wrong**: `fw inception decide` is NOT a Tier 0 command. It does not trip `check-tier0.sh` patterns. No prior human authority is exercised. T-637's intent was probably "do not re-prompt for confirmation"; the effect is "skip every safety check."

**For whom:** Every consumer of `fw inception decide`. Every inception task in the framework's history that ended in `go`/`no-go` since T-637.

**Why now:** /opt/termlink T-909 transcript (2026-04-11) caught the bug red-handed: `fw inception decide T-909 go --rationale "..."` printed `Completing human-owned task (--force bypass)` and `3/3 agent AC unchecked (--force bypass)` and `Partial-complete: 1 human AC(s) pending verification` in a single output block, with the user having only run the decide command. The agent then proceeded to "execute the fix" against an unverified task — an in-progress Human Task Completion Rule violation.

**Severity:** CRITICAL. This is a structural bypass via a back door inside framework code itself, in direct violation of CLAUDE.md §Human Task Completion Rule and §Autonomous Mode Boundaries (which lists "Using --force to bypass any gate" and "Completing human-owned tasks" as NOT delegated).

## Assumptions

A-1: T-637 had a legitimate problem to solve, and the --force was a workaround rather than a deliberate design choice. (Testable by reading the T-637 task file and any related episodic.)

A-2: There is at least one non-bypass solution: split decision-recording from task-completion entirely. `fw inception decide` writes the rationale and decision; the human/agent then runs `fw task update --status work-completed` separately when ACs are actually done. (Testable by sketching the change in `lib/inception.sh` and confirming it preserves T-637's original intent.)

A-3: Removing the `--force` will break some currently-passing inception flows where ACs were never written or never checked. Backwards compat is a real concern. (Testable by counting how many existing inception tasks have empty/unchecked agent AC sections.)

A-4: The "compounding effect" is real — G-032 + G-034 (premature episodic) produces false long-term memory. Fixing G-032 alone may not be enough. (Testable by inspecting `.context/episodic/` for tasks generated under partial-complete state.)

## Exploration Plan

**Phase 1 — Read T-637 history.** Find the T-637 task file and any related episodic. Reconstruct: what problem was being solved? Why was --force the chosen fix? Was a non-bypass alternative considered?

**Phase 2 — Audit call sites.** `grep -rn "inception decide\|inception_decide" .` to find every place that uses or depends on the current behavior. Identify which depend on the --force semantics.

**Phase 3 — Sketch the split.** Write a 5-line patch that removes --force from line 303. Then write the consequence: the user/agent must check ACs and run `fw task update --status work-completed` separately. Identify what this breaks for currently-clean inceptions.

**Phase 4 — Backwards-compat audit.** How many existing inception tasks in `.tasks/completed/` would have failed the gate if --force had not been silently added? Count, sample 5, classify (legitimate completion vs. evaded verification).

**Phase 5 — Recommendation.** GO (remove --force, ship the split, accept the backwards-compat cost) / DEFER (compound risk too high, ship a warning instead) / NO-GO (the bypass is structurally necessary for some reason yet to be discovered).

## Scope Fence

**IN scope:** RCA, audit, recommendation. May read/grep framework source. May write a patch sketch in `docs/reports/T-1101-fw-inception-decide-force-rca.md`.

**OUT of scope:** Actually applying the patch to `lib/inception.sh`. Modifying inception flow. Changing existing inception task files. Re-generating episodic memory. Build work comes from a descendant task after this inception's GO decision.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- A non-bypass alternative exists that preserves T-637's UX (no second command) — CONFIRMED (`--skip-sovereignty`)
- Backwards compat cost is acceptable — CONFIRMED (0/98 historical tasks affected)
- The bug causes real harm — CONFIRMED (T-909 live incident)

**NO-GO if:**
- The `--force` bypass is structurally necessary for reasons not yet discovered — REFUTED
- Removing it would break historical inception flows — REFUTED (0/98 unchecked ACs)

## Verification

test -f docs/reports/T-1101-fw-inception-decide-force-rca.md
grep -q "Recommendation: GO" docs/reports/T-1101-fw-inception-decide-force-rca.md

## Recommendation

**Recommendation:** GO

**Rationale:** The bug is confirmed, the fix is surgical, and the backwards-compat cost is
zero. `lib/inception.sh:303` passes `--force` to `update-task.sh`, bypassing P-010 (AC gate)
and P-011 (verification gate) in addition to the intended R-033 (sovereignty) bypass.
T-637's original intent (no second command after human approval) is fully preserved by
replacing `--force` with a new `--skip-sovereignty` flag that only bypasses R-033.
The T-909 incident proves the bug causes real harm in production.

**Evidence:**
- `lib/inception.sh:303` — confirmed `--force` passed silently, without user knowledge
- `check-tier0.sh:145` — `fw inception decide` IS Tier 0 gated (T-637 premise is true for R-033, not for P-010/P-011)
- `update-task.sh:277` — `--force` explicitly bypasses "acceptance criteria + verification gates"
- **0/98** completed inception tasks had unchecked ACs → backwards compat cost is zero
- T-909 live transcript: `3/3 agent AC unchecked (--force bypass)` confirmed
- T-637 completed in 1 minute, no alternatives recorded — insufficient analysis of `--force` scope
- Full analysis: `docs/reports/T-1101-fw-inception-decide-force-rca.md`

## Structural Upgrade (added 2026-04-11 — chokepoint+test discipline pass per T-1105)

The worker's `--skip-sovereignty` flag is good — narrow-scoped, grep-able, auditable. Upgrade it to fully structural by adding a chokepoint and an invariant test:

**Chokepoint (decompose `--force`):**
- Split `update-task.sh --force` into four narrow flags, each requiring explicit justification:
  - `--skip-sovereignty` (R-033) — used by `fw inception decide` after Tier 0 approval
  - `--skip-acceptance-criteria` (P-010) — never used by framework code; user-only
  - `--skip-verification` (P-011) — never used by framework code; user-only
  - `--skip-human-ownership` — never used by framework code; user-only
- `--force` becomes a deprecated alias that prints a warning and applies all four. New code must use the narrow flags.

**Invariant test:**
- `tests/lint/no-force-in-framework.bats`: greps `lib/ agents/` for `--force` in calls to `update-task.sh`. Allowlist: only the `--skip-sovereignty` site in `lib/inception.sh:303`. Any other use fails CI.

**Audit log:**
- Every non-default flag is logged to `.context/working/.gate-bypass-log.yaml` with `{timestamp, caller, flag, reason}`. Reviewable; surfaces silent bypasses immediately.

**Why this is more reliable than the worker's fix alone:** the worker fix prevents `lib/inception.sh:303` from bypassing AC/verification gates today, but does NOT prevent another framework function from doing the same thing tomorrow. The chokepoint+test pair makes the bug class structurally impossible.

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: The bug is confirmed, the fix is surgical, and the backwards-compat cost is
zero. `lib/inception.sh:303` passes `--force` to `update-task.sh`, bypassing P-010 (AC gate)
and P-011 (verification gate) in addition to the intended R-033 (sovereignty) bypass.
T-637's original intent (no second command after human approval) is fully preserved by
replacing `--force` with a new `--skip-sovereignty` flag that only bypasses R-033.
The T-909 incident proves the bug causes real harm in production.

Evidence:
- `lib/inception.sh:303` — confirmed `--force` passed silently, without user knowledge
- `check-tier0.sh:145` — `fw inception decide` IS Tier 0 gated (T-637 premise is true for R-033, not for P-010/P-011)
- `update-task.sh:277` — `--force` explicitly bypasses "acceptance criteria + verification gates"
- 0/98 completed inception tasks had unchecked ACs → backwards compat cost is zero
- T-909 live transcript: `3/3 agent AC unchecked (--force bypass)` confirmed
- T-637 completed in 1 minute, no alternatives recorded — insufficient analysis of `--force` scope
- Full analysis: `docs/reports/T-1101-fw-inception-decide-force-rca.md`

**Date**: 2026-04-11T20:07:32Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: The bug is confirmed, the fix is surgical, and the backwards-compat cost is
zero. `lib/inception.sh:303` passes `--force` to `update-task.sh`, bypassing P-010 (AC gate)
and P-011 (verification gate) in addition to the intended R-033 (sovereignty) bypass.
T-637's original intent (no second command after human approval) is fully preserved by
replacing `--force` with a new `--skip-sovereignty` flag that only bypasses R-033.
The T-909 incident proves the bug causes real harm in production.

Evidence:
- `lib/inception.sh:303` — confirmed `--force` passed silently, without user knowledge
- `check-tier0.sh:145` — `fw inception decide` IS Tier 0 gated (T-637 premise is true for R-033, not for P-010/P-011)
- `update-task.sh:277` — `--force` explicitly bypasses "acceptance criteria + verification gates"
- 0/98 completed inception tasks had unchecked ACs → backwards compat cost is zero
- T-909 live transcript: `3/3 agent AC unchecked (--force bypass)` confirmed
- T-637 completed in 1 minute, no alternatives recorded — insufficient analysis of `--force` scope
- Full analysis: `docs/reports/T-1101-fw-inception-decide-force-rca.md`

**Date**: 2026-04-11T20:07:32Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-11T20:07:32Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: The bug is confirmed, the fix is surgical, and the backwards-compat cost is
zero. `lib/inception.sh:303` passes `--force` to `update-task.sh`, bypassing P-010 (AC gate)
and P-011 (verification gate) in addition to the intended R-033 (sovereignty) bypass.
T-637's original intent (no second command after human approval) is fully preserved by
replacing `--force` with a new `--skip-sovereignty` flag that only bypasses R-033.
The T-909 incident proves the bug causes real harm in production.

Evidence:
- `lib/inception.sh:303` — confirmed `--force` passed silently, without user knowledge
- `check-tier0.sh:145` — `fw inception decide` IS Tier 0 gated (T-637 premise is true for R-033, not for P-010/P-011)
- `update-task.sh:277` — `--force` explicitly bypasses "acceptance criteria + verification gates"
- 0/98 completed inception tasks had unchecked ACs → backwards compat cost is zero
- T-909 live transcript: `3/3 agent AC unchecked (--force bypass)` confirmed
- T-637 completed in 1 minute, no alternatives recorded — insufficient analysis of `--force` scope
- Full analysis: `docs/reports/T-1101-fw-inception-decide-force-rca.md`

### 2026-04-12T09:30:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T10:05:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Build task T-1142 completed — --force decomposed into narrow flags

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b6b1984a
- **Timestamp:** 2026-06-02T14:55:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
