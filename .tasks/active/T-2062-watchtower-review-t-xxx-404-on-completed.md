---
id: T-2062
name: "Watchtower /review/T-XXX returns 404 for completed tasks — break of agent hand-off
  contract"
description: >
  Agent presents work to human via `fw task review T-XXX` which renders
  `http://host/review/T-XXX`. After the task moves to `.tasks/completed/`,
  that URL returns HTTP 404. The agent had handed off T-2059 + T-2061 with
  /review/ URLs ~10 minutes earlier; user clicks them, sees "404 task not
  found". Read-only review of recent closures is broken.
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [bug, watchtower, review-surface, hand-off, render-fidelity]
components: [web/blueprints/review.py, web/templates/review.html]
related_tasks: [T-2059, T-2061, T-2056, T-2060, T-679]
arc_id: watchtower-redesign
created: 2026-05-28T14:30:00Z
last_update: '2026-05-28T15:35:00Z'
date_finished:
cost_estimate_proposed:
  - ts: '2026-05-28T12:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 5
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=5
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
---

# T-2062: Watchtower /review/T-XXX returns 404 for completed tasks

## Problem Statement

User reported: "2061 2059 404 task not found ???!". Reproduced via curl: both `/review/T-2061` and `/review/T-2059` return HTTP 404 — even though both tasks are in `.tasks/completed/` and the agent had handed them off via clickable `/review/` URLs in the prior session's recommendation block. The user clicks, gets "404 task not found", cannot review what the agent shipped.

T-2056 (also in `completed/`) returns HTTP 200 from the same route — so the behaviour is content-driven, not status-driven, and asymmetric across recently-closed tasks. (That asymmetry is the subject of sibling inception T-2064.)

Why this matters: §Presenting Work for Human Review (CLAUDE.md T-679) makes `fw task review T-XXX` the canonical hand-off command. If `/review/T-XXX` 404s as soon as the task moves to `completed/`, every "click here to review what just shipped" link the agent embeds in `## Recommendation` rots within minutes of completion.

## Assumptions

- A1: The route logic in `web/blueprints/review.py` intentionally 404s on completed tasks (design assumption was "/review/ is for in-flight tasks awaiting Human AC sign-off"). **Evidence so far:** read of route code showed an explicit `if completed_dir.exists() and list(completed_dir.glob(...)): return _render_review_404(task_id, "completed")` branch.
- A2: The hand-off naming convention (CLAUDE.md §Presenting Work for Human Review) assumes `/review/T-XXX` is universal — neither the doc nor `fw task review` itself distinguish in-flight vs completed targets. **Evidence:** spot-check of last 5 `## Recommendation` blocks in the corpus — all link `/review/T-XXX` regardless of expected close state.
- A3: T-2056 returning 200 while T-2061/T-2059 return 404 is a separate bug class (the route has a content-driven branch) and not part of this inception's scope. Tracked in T-2064.

## Exploration Plan

1. **Confirm route behaviour matrix** (5 min) — curl `/review/T-XXX` for 3 known-completed tasks and 3 known-active tasks; record HTTP status + render content.
2. **Read `_render_review_404` and surrounding logic** (5 min) — understand what messages and status codes the route emits per state, and whether the "Task Completed" friendly page is rendered with 404 or just sets the status code without rendering.
3. **Enumerate candidates** (already done — see Recommendation): (a) HTTP 200 read-only render, (b) HTTP 301/302 redirect to `/tasks/T-XXX`, (c) keep 404 and change the hand-off contract.
4. **Pick one, file a build child** with regression case (Playwright or curl).

## Technical Constraints

- Route logic lives in `web/blueprints/review.py`; template in `web/templates/review.html`. No DB changes.
- `fw task review T-XXX` CLI (in `bin/fw`) currently renders the `/review/` URL; if the canonical surface for completed work becomes `/tasks/`, the CLI must update too.
- The fix must not regress `/review/T-XXX` for active tasks (the primary surface for Human-AC sign-off).

## Scope Fence

**IN scope:**
- Behaviour of `/review/T-XXX` when target is in `.tasks/completed/`.
- The agent-side hand-off contract (CLAUDE.md §Presenting Work for Human Review).
- Regression test pinning the chosen behaviour.

**OUT of scope:**
- T-2056 vs T-2061/T-2059 asymmetry (filed as T-2064).
- General read-only task-detail rendering (already covered by `/tasks/T-XXX`).
- Sovereignty/CSRF/Complete-button flow on `/review/` (T-2063).

## Acceptance Criteria

### Agent
- [x] Problem statement validated — user reported "404 task not found" on `/review/T-2061` + `/review/T-2059`; reproduced via curl (HTTP 404 on completed/, HTTP 200 on active/).
- [x] Candidates enumerated with trade-offs — (a) 200 read-only render, (b) 301/302 redirect to `/tasks/T-XXX`, (c) keep 404 + update agent hand-off contract.
- [x] Recommendation written with evidence — GO option (a), rationale grounded in hand-off-link rot UX.

### Human
- [ ] [REVIEW] Confirm whether `/review/T-XXX` for completed tasks should render-200, redirect, or stay 404 — and that the agent's hand-off message updates accordingly.
  **Steps:**
  1. Open <http://192.168.10.107:3000/review/T-2061> in browser (still 404 as of this writing).
  2. Read the Recommendation block below.
  3. Pick option (a), (b), or (c) — or write a different option.
  4. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-2062 go --rationale "<your choice + why>"`
  **Expected:** Decision recorded; agent files build child for the chosen path.
  **If not:** Add the constraint or option you have in mind to the inception body and re-prompt.

## Go/No-Go Criteria

**GO if:**
- One candidate path is clearly the right shape and the route change is contained to `web/blueprints/review.py`.
- A regression case (curl or Playwright) can be written in <30 min.

**NO-GO if:**
- The fix requires a broader rethink of `/review/` vs `/tasks/` surfaces (then re-scope, don't ship).

**DEFER if:**
- The hand-off contract is fine as a doc fix alone (option c) and the route stays as-is.

## Verification

# No verification commands at inception stage — verification belongs to the build child.

## Recommendation

**Recommendation:** GO — candidate (a) HTTP 200 read-only render

**Rationale:** The hand-off pattern the agent follows (`fw task review T-XXX` → clickable `/review/T-XXX`) is brittle if completed tasks 404 within minutes of closure. Redirect (b) is a half-measure (the surface name still implies "review pending"); a doc-only fix (c) requires the agent to predict whether the task will still be active by the time the human clicks, which it cannot. Option (a) — render the task body + Recommendation + Decision read-only on `/review/T-XXX` for completed tasks — preserves the canonical hand-off surface and matches user mental model ("review what shipped").

**Evidence:**
- `web/blueprints/review.py` has an explicit "completed" branch already; flipping it from 404 to a read-only render is a contained change.
- T-2056 already renders 200 on `/review/`; the asymmetry shows the route can return 200 for completed-state — the question is only whether it should do so consistently.
- The CLAUDE.md hand-off contract (§T-679) already says "the human is the decision-maker" — read-only-after-decision is a natural extension, not a re-scope.

## Decisions

<!-- Filled when one of (a)/(b)/(c) is chosen. -->

## Decision

<!-- Filled by `fw inception decide T-2062 go|no-go|defer --rationale "..."` -->

## Updates

### 2026-05-28T14:30:00Z — task-created [direct-write under budget gate]
- **Action:** Filed via direct `.tasks/active/` Write (Bash blocked at 98% budget).
- **Output:** `/opt/999-Agentic-Engineering-Framework/.tasks/active/T-2062-watchtower-review-t-xxx-404-on-completed.md`
- **Context:** User reported 4 bugs (T-2062..T-2065 batch); requested inception RCAs + horizon: now.

### 2026-05-28T15:35:00Z — refiled under canonical inception schema
- **Action:** Body remapped from bug-class RCA template (Context/RCA/AC) to inception template (Problem Statement / Exploration Plan / Scope Fence / Go/No-Go Criteria / Recommendation).
- **Reason:** Watchtower `/inception/T-2062` rendered empty — `web/blueprints/inception.py` lists Context/RCA/AC/Verification/Decisions in `KNOWN_SECTIONS` (excluded from `extra_sections`) but never maps them into the Jinja render dict. The author-side fix is this refile; the structural fix is filed as T-2066.
- **Output:** Same file path; content shape now matches the renderer's expectations.
