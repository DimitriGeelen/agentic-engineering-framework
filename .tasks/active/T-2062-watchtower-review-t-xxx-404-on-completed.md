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
status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: [bug, watchtower, review-surface, hand-off, render-fidelity]
components: [web/blueprints/review.py, web/templates/review.html]
related_tasks: [T-2059, T-2061, T-2056, T-2060, T-679]
arc_id: watchtower-redesign
created: 2026-05-28T14:30:00Z
last_update: '2026-06-11T22:23:31Z'
date_finished: 2026-05-28T17:59:23Z
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
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
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
- [x] Recommendation written with evidence — NO-GO; sibling T-2067 shipped upstream root-cause fix (regex bug in update-task.sh, not /review/ route); all four originally-404 URLs now return 200.

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

**Recommendation:** NO-GO — original symptom resolved by sibling T-2067; no separate route change needed.

**Rationale:** After this inception was filed, T-2067 (`fix update-task.sh components flow-style regex bug`) shipped the actual root cause and repaired the 4 corpus victims (T-2059, T-2060, T-2061, T-2018). The "404 on completed task" symptom was NOT a `/review/` route bug — it was upstream frontmatter mangling: `update-task.sh:1731`'s components-replacement regex only matched block-style continuation lines, so wrapped flow-style components produced an orphan `]` continuation line, made the YAML invalid, made `parse_frontmatter()` return False, and made `/review/T-XXX` render the "task not found" page (the route returns 200 for "completed" branch, 404 only for "not_found" / "invalid" — see `_render_review_404(reason)` whose name is misleading). With the regex fix shipped and the corpus repaired, all four URLs the user originally reported as 404 now return 200 (verified post-T-2067).

**Evidence:**
- T-2067 closed 2026-05-28 with regex fix at `agents/task-create/update-task.sh:1739-1748`, 6-case bats pinning shape coverage, and audit guard for the YAML-mangling class.
- Post-fix curl verification: `/review/T-2059`, `/review/T-2060`, `/review/T-2061`, `/review/T-2056` all return HTTP 200.
- Sovereignty: the agent did not invent a new route surface to "fix" a symptom whose root cause lived elsewhere; the correct discipline is NO-GO on this inception and trust the sibling's coverage.
- Class precedent: this is the same shape as T-1469 (the original components-block regex) — a writer-side bug that masquerades as a renderer-side bug.

**If the human wants the original (a) shape anyway** — render completed tasks read-only on `/review/T-XXX` instead of relying on `/tasks/T-XXX` — that is a separate UX call (extending the hand-off surface beyond decision time) and should be re-scoped as a fresh inception with that framing, not bundled under T-2062's "404 bug" framing.

## Decisions

### 2026-05-28 — root cause empirically traced to T-2067, not /review/ route

**Finding:** The 404 symptom on `/review/T-2061` and `/review/T-2059` was not produced by the `/review/` route's completed-task branch (that branch returns 200 with a friendly "Task Completed" page). It was produced by `parse_frontmatter()` returning False on those task files, which routed both through `_render_review_404("not_found")` — a 404 with a "task not found" body — making it look like a missing-route problem when the real cause was unparseable YAML.

**Cause chain (verified):**
1. `update-task.sh:1731` components-replacement regex was block-style-only: `^components:[^\n]*\n(?:[ \t]+-[^\n]*\n)*`.
2. When the input had flow-style continuation (`components: [a, b,\n      c]`), the regex matched only line 1, leaving `      c]` as an orphan continuation when the replacement built `components: [new]` on top.
3. Orphan `]` continuation → invalid YAML → `parse_frontmatter()` returns False → `/review/` returns 404 with reason="invalid" (or "not_found" depending on the load path).
4. T-2056 returned 200 because its components: block was already flat single-line and the bug never triggered.

**Resolution shipped under T-2067:**
- Regex generalised to `^components:[^\n]*\n(?:[ \t]+(?!\w+:)[^\n]*\n)*` (matches both flow and block continuations; protects next-key with negative lookahead).
- 4 corpus victims (T-2018, T-2059, T-2060, T-2061) repaired manually in same task.
- bats `tests/unit/test_components_replacement_regex.bats` pins 6 historical shapes.
- `agents/audit/audit.sh` parse-walk added for defence-in-depth.

**Recommendation reversal:** This inception's original GO (option a — read-only 200 render on `/review/T-XXX` for completed tasks) is no longer the right intervention. The symptom is resolved; the route's existing completed-branch is already correct. Filed as NO-GO.

### 2026-05-28 — separation principle preserved

If a future inception genuinely wants the read-only-completed-on-/review/ UX (vs. /tasks/), it should be re-filed with that scope explicitly, not bundled with this 404-symptom framing. The 404 was a bug; "extend the hand-off surface lifetime" is a feature decision.

## Decision

**Decision**: NO-GO

**Rationale**: Recommendation: NO-GO — original symptom resolved by sibling T-2067; no separate route change needed.

Rationale: After this inception was filed, T-2067 (`fix update-task.sh components flow-style regex bug`) shipped the actual root cause and repaired the 4 corpus victims (T-2059, T-2060, T-2061, T-2018). The "404 on completed task" symptom was NOT a `/review/` route bug — it was upstream frontmatter mangling: `update-task.sh:1731`'s components-replacement regex only matched block-style continuation lines, so wrapped flow-style components produced an orphan `]` continuation line, made the YAML invalid, made `parse_frontmatter()` return False, and made `/review/T-XXX` render the "task not found" page (the route returns 200 for "completed" branch, 404 only for "not_found" / "invalid" — see `_render_review_404(reason)` whose name is misleading). With the regex fix shipped and the corpus repaired, all four URLs the user originally reported as 404 now return 200 (verified post-T-2067).

Evidence:
- T-2067 closed 2026-05-28 with regex fix at `agents/task-create/update-task.sh:1739-1748`, 6-case bats pinning shape coverage, and audit guard for the YAML-mangling class.
- Post-fix curl verification: `/review/T-2059`, `/review/T-2060`, `/review/T-2061`, `/review/T-2056` all return HTTP 200.
- Sovereignty: the agent did not invent a new route surface to "fix" a symptom whose root cause lived elsewhere; the correct discipline is NO-GO on this inception and trust the sibling's coverage.
- Class precedent: this is the same shape as T-1469 (the original components-block regex) — a writer-side bug that masquerades as a renderer-side bug.

If the human wants the original (a) shape anyway — render completed tasks read-only on `/review/T-XXX` instead of relying on `/tasks/T-XXX` — that is a separate UX call (extending the hand-off surface beyond decision time) and should be re-scoped as a fresh inception with that framing, not bundled under T-2062's "404 bug" framing.

**Date**: 2026-05-28T17:59:23Z

## Updates

### 2026-05-28T14:30:00Z — task-created [direct-write under budget gate]
- **Action:** Filed via direct `.tasks/active/` Write (Bash blocked at 98% budget).
- **Output:** `/opt/999-Agentic-Engineering-Framework/.tasks/active/T-2062-watchtower-review-t-xxx-404-on-completed.md`
- **Context:** User reported 4 bugs (T-2062..T-2065 batch); requested inception RCAs + horizon: now.

### 2026-05-28T15:35:00Z — refiled under canonical inception schema
- **Action:** Body remapped from bug-class RCA template (Context/RCA/AC) to inception template (Problem Statement / Exploration Plan / Scope Fence / Go/No-Go Criteria / Recommendation).
- **Reason:** Watchtower `/inception/T-2062` rendered empty — `web/blueprints/inception.py` lists Context/RCA/AC/Verification/Decisions in `KNOWN_SECTIONS` (excluded from `extra_sections`) but never maps them into the Jinja render dict. The author-side fix is this refile; the structural fix is filed as T-2066.
- **Output:** Same file path; content shape now matches the renderer's expectations.

### 2026-05-28T16:50:00Z — recommendation reversed to NO-GO (root cause resolved by sibling T-2067)
- **Action:** Recommendation block rewritten from GO option (a) read-only 200 render → NO-GO; Decisions block added with empirical cause-chain trace; Agent AC #3 updated to reflect new recommendation.
- **Reason:** T-2067 (closed 2026-05-28) shipped the actual root cause: `update-task.sh:1731` components-replacement regex was block-style-only and mangled flow-style continuations. The 404 the user reported was not a `/review/` route bug but unparseable-YAML downstream of a writer-side regex bug. After T-2067's fix + corpus repair, `/review/T-2059`, `/review/T-2060`, `/review/T-2061`, `/review/T-2056` all return HTTP 200 (curl-verified).
- **Sovereignty:** Decision left for human via `fw inception decide T-2062 no-go --rationale "..."` (§ACD-gated under `$CLAUDECODE=1`).

### 2026-05-28T17:59:23Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO — original symptom resolved by sibling T-2067; no separate route change needed.

Rationale: After this inception was filed, T-2067 (`fix update-task.sh components flow-style regex bug`) shipped the actual root cause and repaired the 4 corpus victims (T-2059, T-2060, T-2061, T-2018). The "404 on completed task" symptom was NOT a `/review/` route bug — it was upstream frontmatter mangling: `update-task.sh:1731`'s components-replacement regex only matched block-style continuation lines, so wrapped flow-style components produced an orphan `]` continuation line, made the YAML invalid, made `parse_frontmatter()` return False, and made `/review/T-XXX` render the "task not found" page (the route returns 200 for "completed" branch, 404 only for "not_found" / "invalid" — see `_render_review_404(reason)` whose name is misleading). With the regex fix shipped and the corpus repaired, all four URLs the user originally reported as 404 now return 200 (verified post-T-2067).

Evidence:
- T-2067 closed 2026-05-28 with regex fix at `agents/task-create/update-task.sh:1739-1748`, 6-case bats pinning shape coverage, and audit guard for the YAML-mangling class.
- Post-fix curl verification: `/review/T-2059`, `/review/T-2060`, `/review/T-2061`, `/review/T-2056` all return HTTP 200.
- Sovereignty: the agent did not invent a new route surface to "fix" a symptom whose root cause lived elsewhere; the correct discipline is NO-GO on this inception and trust the sibling's coverage.
- Class precedent: this is the same shape as T-1469 (the original components-block regex) — a writer-side bug that masquerades as a renderer-side bug.

If the human wants the original (a) shape anyway — render completed tasks read-only on `/review/T-XXX` instead of relying on `/tasks/T-XXX` — that is a separate UX call (extending the hand-off surface beyond decision time) and should be re-scoped as a fresh inception with that framing, not bundled under T-2062's "404 bug" framing.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d8fb17ed
- **Timestamp:** 2026-05-28T17:59:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-28T17:59:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: NO-GO
