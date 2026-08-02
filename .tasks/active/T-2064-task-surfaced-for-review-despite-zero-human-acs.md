---
id: T-2064
name: "Task surfaced for human review despite zero Human ACs — review-queue filter
  gap"
description: >
  T-2056 is in `.tasks/completed/` with 4 Agent ACs ticked and zero Human ACs
  (### Human heading present but body empty — only template comments). User
  sees it surfaced in human-facing UI (HTTP 200 on /review/T-2056), asks
  "non an human ac, why surface to human ??". The review/approvals surface
  filters on owner or status but doesn't filter on "actually has Human ACs > 0".
status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: [bug, watchtower, review-queue, filter-gap, sovereignty]
components: [web/blueprints/review.py, web/blueprints/approvals.py, bin/fw, 
      agents/task-create/update-task.sh]
related_tasks: [T-2056, T-2061, T-679, T-372, T-373]
arc_id: watchtower-redesign
created: 2026-05-28T14:30:00Z
last_update: '2026-06-11T22:23:31Z'
date_finished: 2026-05-28T17:59:50Z
cost_estimate_proposed:
  - ts: '2026-05-28T12:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 5
      tier: 4
      effort: 6
    rationale: blast_radius=5 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-28T13:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:31Z'
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
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-2064: Task surfaced for human review despite zero Human ACs

## Problem Statement

User: "2056 non an human ac, why surface to human ??".

Verified:
- T-2056 is in `.tasks/completed/` (closed in this session via T-2061's predicate fix).
- T-2056's `### Human` AC section contains ONLY the template guidance comment — no actual `- [ ] [REVIEW] ...` lines.
- `curl /review/T-2056` returns HTTP 200 (not 404 like T-2061 / T-2059 which is a sibling bug, T-2062).
- T-2056 has Agent ACs only (4 of them, all ticked).

The review surface is showing T-2056 to the human anyway. Why?

Two candidate explanations:
- (i) The 404 path triggers on `completed_dir` glob (T-2062's concern), but T-2056 hits a different code path returning 200 — likely because of how its frontmatter, AC structure, or Recommendation parses.
- (ii) The review-queue / approvals surface filters by "task in some specific state" (e.g. owner=human, has Recommendation, recently-closed) without checking "has unchecked Human ACs > 0".

Cross-reference: `fw review-queue` lists 118 tasks awaiting Human AC verification. If T-2056 (zero Human ACs) appears in that count, the filter is broken.

## Assumptions

- A1: T-2056 returning 200 while T-2061/T-2059 return 404 (all three in `completed/`) is content-driven — likely "has Recommendation block" or "has Decision pending" branch in `review.py`.
- A2: `fw review-queue` (CLI) builds its list by walking active/completed tasks and applying a filter; that filter does NOT check "unchecked-Human-AC count > 0".
- A3: `/approvals` page (`web/blueprints/approvals.py`) builds its list similarly and likely shares or replicates the same filter logic.

## Exploration Plan

1. **Trace the 200 path for T-2056** (10 min) — read `web/blueprints/review.py` for the branch that returns 200 vs 404, identify the discriminator.
2. **Trace `fw review-queue`** (5 min) — read the CLI's filter predicate, count tasks with zero Human ACs in the output.
3. **Trace `/approvals` page** (5 min) — read approvals.py, compare its predicate to the CLI.
4. **Pick fix candidate:** (a) add `has_unchecked_human_acs > 0` predicate at the render-time filter, (b) push the predicate to the queue-build layer so CLI + web agree, (c) auto-tick zero-Human-AC tasks at completion (close the loop at the closure boundary instead of filtering at the surface).
5. **File build child.**

## Technical Constraints

- The predicate must read AC structure reliably — i.e. understand the `### Human` heading + `- [ ]` / `- [x]` line counting, NOT just text presence.
- T-1985's [REVIEWER] auto-tick must not break (auto-ticked Human ACs should disappear from the queue legitimately).
- Sovereignty rail: the predicate should NEVER tick a Human AC; it should only decide visibility.

## Scope Fence

**IN scope:**
- The visibility predicate for `fw review-queue`, `/review/T-XXX` (when 200-rendered), and `/approvals`.
- A regression case asserting "completed task with zero Human ACs is NOT surfaced" + "completed task with unchecked Human AC IS surfaced".

**OUT of scope:**
- The 404-vs-200 asymmetry (T-2062 — owns that).
- The Complete-button silent-fail (T-2063).
- AC-classification guidance for authors (already in CLAUDE.md §AC Classification Guidance).

## Acceptance Criteria

### Agent
- [x] Problem statement validated — T-2056 (zero Human ACs, completed) renders HTTP 200 on `/review/T-2056` while T-2061/T-2059 return 404; user flagged "non an human ac, why surface to human".
- [x] Assumptions enumerated — A1 (200 path is content-driven branch), A2 (`fw review-queue` doesn't check "unchecked-Human-AC count > 0"), A3 (`/approvals` shares the same gap).
- [x] Candidates enumerated — (a) render-time edge filter, (b) shared helper at queue-build layer, (c) auto-tick at completion (sovereignty-risky).
- [x] Recommendation written with evidence — GO option (b), rationale grounded in single definition + three call sites, sovereignty rail intact.

### Human
- [ ] [REVIEW] After remediation, the human review queue and `/review/T-XXX` paths surface ONLY tasks with at least one unchecked Human AC.
  **Steps:**
  1. Visit <http://192.168.10.107:3000/review/T-2056> after fix — expect 404 or redirect to `/tasks/T-2056` (read-only).
  2. Visit <http://192.168.10.107:3000/approvals> — confirm zero-Human-AC tasks are absent.
  3. Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw review-queue` — confirm count drops by the number of zero-Human-AC tasks currently mis-surfaced.
  **Expected:** No zero-Human-AC tasks visible in any of the three surfaces.
  **If not:** Sample one mis-surfaced task and re-file.

## Go/No-Go Criteria

**GO if:**
- The predicate change is contained to 2-3 files (CLI queue builder + review.py route + approvals.py route, or a shared helper they all call).
- Regression case can be pinned in <30 min.

**NO-GO if:**
- The fix requires reworking the AC-parser library (broader refactor).

**DEFER if:**
- The mis-surfacing is rare in practice (audit shows <5 instances corpus-wide) and the human is comfortable with the noise.

## Verification

# Confirm current symptom:
# T-2727/OBS-127: was a literal :3000 (T-1376 anti-pattern) — reached another
# project's watchtower. Resolved URL returns 200 for this endpoint.
curl -sf -o /dev/null "$(bin/fw watchtower url)/review/T-2056"
# T-2056 is in completed/ with zero Human ACs but route returns 200

## Recommendation

**Recommendation:** GO — candidate (b) push the predicate to the queue-build layer (shared helper).

**Rationale:** Filtering at the render-time edge (a) means three surfaces each maintain the same logic — drift-prone. Auto-ticking at completion (c) is sovereignty-risky (the agent should never tick `### Human` ACs). A shared helper `has_unfinished_human_work(task_file) -> bool` consumed by CLI queue builder, `/review/` route, and `/approvals/` route is the right shape — one definition, three call sites, single regression case.

**Evidence:**
- The CLAUDE.md rule "NEVER check a `### Human` AC" (sovereignty boundary) rules out candidate (c).
- T-1985's auto-tick already exists for `[REVIEWER]`-prefixed ACs but explicitly stops at sovereignty for `[REVIEW]` — the auto-tick mechanism is not the right place to filter visibility.
- `fw review-queue` and `/approvals` and `/review/` are three surfaces; one helper de-duplicates the predicate.

## Decisions

<!-- Filled when GO/NO-GO/DEFER chosen. -->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — candidate (b) push the predicate to the queue-build layer (shared helper).

Rationale: Filtering at the render-time edge (a) means three surfaces each maintain the same logic — drift-prone. Auto-ticking at completion (c) is sovereignty-risky (the agent should never tick `### Human` ACs). A shared helper `has_unfinished_human_work(task_file) -> bool` consumed by CLI queue builder, `/review/` route, and `/approvals/` route is the right shape — one definition, three call sites, single regression case.

Evidence:
- The CLAUDE.md rule "NEVER check a `### Human` AC" (sovereignty boundary) rules out candidate (c).
- T-1985's auto-tick already exists for `[REVIEWER]`-prefixed ACs but explicitly stops at sovereignty for `[REVIEW]` — the auto-tick mechanism is not the right place to filter visibility.
- `fw review-queue` and `/approvals` and `/review/` are three surfaces; one helper de-duplicates the predicate.

**Date**: 2026-05-28T17:59:49Z

## Updates

### 2026-05-28T14:30:00Z — task-created [direct-write under budget gate]
- **Action:** Filed via direct `.tasks/active/` Write (Bash blocked at 98% budget).
- **Context:** User reported 4 bugs (T-2062..T-2065 batch). T-2056 is the canonical case.

### 2026-05-28T15:35:00Z — refiled under canonical inception schema
- **Action:** Body remapped from bug-class RCA template to inception template.
- **Reason:** Watchtower `/inception/T-2064` rendered empty — see T-2066 for the structural fix.

### 2026-05-28T17:59:49Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — candidate (b) push the predicate to the queue-build layer (shared helper).

Rationale: Filtering at the render-time edge (a) means three surfaces each maintain the same logic — drift-prone. Auto-ticking at completion (c) is sovereignty-risky (the agent should never tick `### Human` ACs). A shared helper `has_unfinished_human_work(task_file) -> bool` consumed by CLI queue builder, `/review/` route, and `/approvals/` route is the right shape — one definition, three call sites, single regression case.

Evidence:
- The CLAUDE.md rule "NEVER check a `### Human` AC" (sovereignty boundary) rules out candidate (c).
- T-1985's auto-tick already exists for `[REVIEWER]`-prefixed ACs but explicitly stops at sovereignty for `[REVIEW]` — the auto-tick mechanism is not the right place to filter visibility.
- `fw review-queue` and `/approvals` and `/review/` are three surfaces; one helper de-duplicates the predicate.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-84880a65
- **Timestamp:** 2026-05-28T17:59:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-28T17:59:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
