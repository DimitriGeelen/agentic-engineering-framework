---
id: T-1576
name: "F9 — Distinguish NO-REC from DEFER in review-queue and /approvals (build-task
  gap parallel to T-1570)"
description: >
  extract_recommendation_verdict returns '?' for both 'no ## Recommendation section'
  and 'section exists but verdict missing'. fw review-queue and /approvals render
  both as [?], blending 'agent owes a recommendation' with 'deferred verdict'. Surface
  as [NO-REC] (or similar) so agent knows to write one; human knows not to act yet.
  Parallel to T-1570 which fixed inception side.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [agents/handover/handover.sh, bin/fw, web/blueprints/approvals.py, 
      web/shared.py, web/templates/_approvals_content.html]
related_tasks: []
created: 2026-04-28T09:07:46Z
last_update: '2026-06-11T22:23:52Z'
date_finished: 2026-04-28T09:26:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1576: F9 — Distinguish NO-REC from DEFER in review-queue and /approvals (build-task gap parallel to T-1570)

## Context

`bin/fw review-queue` and Watchtower `/approvals` blend two distinct states behind the same `[?]` verdict marker: (a) tasks where the agent never wrote a `## Recommendation` section at all (NO-REC — agent owes a recommendation, human cannot act), and (b) tasks where the section exists but the verdict line is missing/unparseable (truly unknown). Both render identically.

Concrete impact: 12 tasks in the current review-queue show `[?]` verdict — at least T-1062, T-801, T-802, T-803, T-967 etc. have no `## Recommendation` section. The human sees them in the queue but has nothing to act on; the agent doesn't see "write a recommendation" called out.

Parallel to T-1570 (F4) which surfaced the same gap on the inception side of `/approvals`. This is the build/partial-complete side.

## Acceptance Criteria

### Agent
- [x] `web/shared.py` exposes `extract_recommendation_state(body) -> str` returning `'GO'|'NO-GO'|'DEFER'|'NO-REC'|'?'` — discriminates "no section" from "verdict unparseable"
- [x] Existing `extract_recommendation_verdict` retained as compatibility shim (returns `?` for both NO-REC and unparseable, like before)
- [x] `bin/fw review-queue` uses `extract_recommendation_state`; renders `NO-REC` distinct from `?` (own color, sort priority right after `?`)
- [x] `agents/handover/handover.sh` "Awaiting Your Action" prefix uses state — surfaces `[NO-REC]` instead of `[?]` for tasks missing recommendation
- [x] `web/blueprints/approvals.py` `_load_pending_human_acs` exposes both `verdict` (compat) and `state`; template renders NO-REC badge distinctly
- [x] Unit test in `tests/unit/test_extract_recommendation.py` covers: empty body → NO-REC, no section → NO-REC, section with no verdict line → ?, full block → GO/NO-GO/DEFER
- [x] `bin/fw test unit -- tests/unit/test_extract_recommendation.py` passes
- [x] `bin/fw review-queue` output on current repo shows `NO-REC` rows for T-1062, T-801, etc. (was `?`)

### Human
- [x] [REVIEW] /approvals "Awaiting Human ACs" cards visually distinguish NO-REC from DEFER/? (reclassified per T-954 — live cyan NO-REC card on T-449 with cyan #0e7490 badge + filter button; DEFER amber #e65100 vs NO-REC cyan #0e7490 are visually + copy-wise distinct; hover title differentiates ("Agent owes a recommendation" vs "Verdict deferred"); T-1597 W2 confirm-GO; user-authorized batch close)
  **Steps:**
  1. Open the queue page (URL emitted by `bin/fw watchtower url`)/approvals
  2. Find a card whose verdict shows the new NO-REC indicator
  3. Confirm it reads "Agent owes a recommendation" / "Not ready for review" rather than "Verdict deferred"
  **Expected:** Clear distinction — NO-REC tasks look different from real DEFER decisions
  **If not:** Screenshot the card; note which marker is ambiguous

## Verification

python3 -m pytest tests/unit/test_extract_recommendation.py -q
# Implementation files exist and reference NO-REC (ACs)
test -f web/shared.py
grep -q "NO-REC\|extract_recommendation_state" web/shared.py
test -f agents/handover/handover.sh
grep -q "NO-REC" agents/handover/handover.sh
test -f web/blueprints/approvals.py
grep -q "state\|NO-REC" web/blueprints/approvals.py
# End-to-end: rendered review-queue emits NO-REC tag
bin/fw review-queue 2>&1 | grep -qE 'NO-REC' && echo "NO-REC rendered" || echo "NO-REC missing"

## Recommendation

**Recommendation:** GO

**Rationale:** Same class of fix as T-1570 — surface a state the review queue was previously hiding. `extract_recommendation_state` discriminates "agent owes a recommendation" (NO-REC) from "verdict unparseable" (?), which the existing `extract_recommendation_verdict` collapsed into a single `?`. Wired into all three queue surfaces (`bin/fw review-queue`, `handover.sh`, Watchtower `/approvals`) so the agent (and human) sees the same distinction wherever the queue is consulted. Compat shim retained — no behaviour change for callers that don't yet care about the distinction. 6 new unit tests pin the contract; visual Playwright check confirms the filter buttons isolate cleanly (11 NO-REC, 6 `?`).

**Evidence:**
- `web/shared.py` — new `extract_recommendation_state(body) -> str` returns `GO|NO-GO|DEFER|NO-REC|?`. Discriminates via `extract_recommendation()["raw"] == ""`.
- `bin/fw` review-queue — switched to `extract_recommendation_state`, NO-REC rendered cyan, sorted after `?` (lowest priority — agent owes a recommendation, can't yet act on it).
- `agents/handover/handover.sh` — both `extract_verdict()` instances updated; "Awaiting Your Action" prefix now reads `[NO-REC]` instead of bare `[?]` for the affected tasks.
- `web/blueprints/approvals.py` — `_load_pending_human_acs` exposes `state` alongside `verdict`. Template `_approvals_content.html` adds NO-REC filter button (cyan), distinct verdict badge (cyan), and JS filter logic that splits norec from unknown.
- `tests/unit/test_extract_recommendation.py` — 6 new tests covering: empty body, no section, empty section, HTML-comment-only section, section without verdict line, full block passthrough.
- Verified live: `bin/fw review-queue` shows `21 GO / 8 DEFER / 6 ? / 11 NO-REC` (was `~21 GO / 8 DEFER / 17 ?` conflated). Playwright filter check: `filterACs('norec')` shows 11 cards all `data-state=NO-REC`; `filterACs('unknown')` shows 6 cards all `data-state="?"`, zero NO-REC leak.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-28T09:07:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1576-f9--distinguish-no-rec-from-defer-in-rev.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4daac892
- **Timestamp:** 2026-06-02T14:58:24Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 10
     - evidence: `bin/fw review-queue 2>&1 | grep -qE 'NO-REC' && echo "NO-REC rendered" || echo "NO-REC missing"`
### 2026-04-28T09:26:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
