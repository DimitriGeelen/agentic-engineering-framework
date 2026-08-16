---
id: T-1577
name: "F10 — extend NO-REC distinction to landing-page Action Required widget (T-1576
  follow-up)"
description: >
  F10 — extend NO-REC distinction to landing-page Action Required widget (T-1576 follow-up)

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [web/blueprints/cockpit.py, web/templates/cockpit.html]
related_tasks: []
created: 2026-04-28T10:42:51Z
last_update: '2026-08-16T22:24:37Z'
date_finished: 2026-04-28T11:07:42Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=1 (body:episodic-only); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1577: F10 — extend NO-REC distinction to landing-page Action Required widget (T-1576 follow-up)

## Context

T-1576 distinguished NO-REC from `?` on `bin/fw review-queue`, `agents/handover/handover.sh`, and Watchtower `/approvals`. The landing-page **Action Required** widget (`web/templates/cockpit.html:131-175`) was not in T-1576's scope and still conflates the two states behind a single `?` pill.

`web/blueprints/cockpit.py:96` calls `extract_recommendation_verdict` (compat shim) and `:151` aggregates `verdict in ("?", None)` into `unknown_ac_count`. That count powers the cockpit `?` pill (`cockpit.html:169-173`) — so a task missing the `## Recommendation` section entirely renders the same as one with an unparseable verdict, exactly the gap T-1576 closed elsewhere.

L-298 (count divergence across UI surfaces) and L-309 (two systems with different definitions of "needs human") both flag this kind of cross-surface drift as the failure mode worth catching now.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/cockpit.py:get_human_verify_tasks` adds a `state` field per task using `extract_recommendation_state` (alongside existing `verdict` for backwards compat)
- [x] `web/blueprints/cockpit.py:get_action_summary` adds `no_rec_ac_count` (state == NO-REC) and updates `unknown_ac_count` to exclude NO-REC (state == "?" only)
- [x] `web/templates/cockpit.html` renders a NO-REC pill (cyan #0e7490, distinct from `?`) when `no_rec_ac_count > 0`
- [x] `?` pill tooltip clarifies it now means "verdict unparseable" — separate from "agent owes a recommendation"
- [x] Counts on cockpit landing page match `/approvals` (NO-REC count, `?` count) — no divergence (L-298)
- [x] Playwright/screenshot evidence captured per L-310: actual rendered DOM verified, not just template grep
- [x] `python3 -m pytest tests/unit/test_extract_recommendation.py -q` passes (no regression)

### Human
- [x] [REVIEW] Cockpit landing-page Action Required pills visually match `/approvals` filter buttons (reclassified per T-954 — count parity verified live: cockpit NO-REC = approvals NO-REC = 1, Python eval against `cockpit.get_action_summary()` matches rendered pills exactly; T-1597 W1 confirm-GO; user-authorized batch close)
  **Steps:**
  1. Open `$(bin/fw watchtower url)` in browser (cockpit landing page)
  2. Locate the "Action Required" card; confirm pill row shows `N GO`, `N DEFER`, `N NO-GO`, `N NO-REC` (cyan), `N ?` (separate)
  3. Open `$(bin/fw watchtower url)/approvals` in another tab; confirm the NO-REC and `?` filter button counts match the cockpit pills exactly
  **Expected:** Cockpit and `/approvals` agree on NO-REC count and `?` count
  **If not:** Screenshot both surfaces; note which surface diverges and by how much

## Verification

python3 -m pytest tests/unit/test_extract_recommendation.py -q
# Template file exists and contains NO-REC rendering (AC#3)
test -f web/templates/cockpit.html
grep -q "NO-REC" web/templates/cockpit.html
# End-to-end: rendered landing page emits NO-REC pill when applicable
curl -sf "$(bin/fw watchtower url)/" | grep -qE 'NO-REC' && echo "NO-REC pill present" || echo "NO-REC pill missing"
python3 -c "from web.blueprints.cockpit import get_action_summary; s = get_action_summary(); assert 'no_rec_ac_count' in s, 'no_rec_ac_count missing from action_summary'; print('action_summary has no_rec_ac_count:', s['no_rec_ac_count'])"

## Recommendation

**Recommendation:** GO

**Rationale:** Same class of fix as T-1576 — extend NO-REC vs `?` distinction to the one queue surface T-1576 didn't cover (the cockpit Action Required widget). Implementation is purely additive at the surface level: new pill, new aggregate count, retuned tooltip. While verifying parity with `/approvals` (the explicit AC), found a parallel bug — cockpit's local AC regex matched template HTML comments, over-counting by 2 against the canonical `_parse_acceptance_criteria` parser. Refactored cockpit to call the canonical parser instead of maintaining its own regex (eliminates parser drift, addresses L-298 / L-309 root cause). One parser is the right number; two definitions of "Human AC" was the actual structural gap. Visual verification per L-310 (Playwright screenshots, DOM eval) — counts agree exactly across both surfaces post-fix.

**Evidence:**
- `web/blueprints/cockpit.py:get_human_verify_tasks` — refactored to call `_parse_acceptance_criteria` from `web/blueprints/tasks.py`. Body extraction strips frontmatter before parsing. Adds `state` field per task.
- `web/blueprints/cockpit.py:get_action_summary` — adds `no_rec_ac_count`, retunes `unknown_ac_count` to exclude NO-REC.
- `web/templates/cockpit.html:168-184` — adds NO-REC pill (cyan `#0e7490`) before `?` pill; both tooltips disambiguated.
- Playwright DOM eval (cockpit landing page): `[{verdict: "GO", text: "26 GO"}, {verdict: "DEFER", text: "8 DEFER"}, {verdict: "NO-REC", text: "11 NO-REC", bg: "rgb(14, 116, 144)"}, {verdict: "?", text: "6 ?"}]`
- Cross-surface parity check (post-refactor): `cockpit NO-REC = 11, approvals NO-REC = 11, diff = empty set`. Same for `?` (6 == 6).
- Total Human AC count corrected from 61/53-tasks → 59/51-tasks (T-1274 and T-1542 had only template-comment ACs; correctly excluded by canonical parser).
- `python3 -m pytest tests/unit/test_extract_recommendation.py -q` → 19 passed in 0.21s.
- Commit: `1d5ef506f T-1577: F10 — distinguish NO-REC from ? on cockpit Action Required widget`.

**Reach:** Closes the artifact/inception approval review arc's last queue surface. T-1576 fixed CLI (`fw review-queue`), `/approvals`, and handover; T-1577 fixes the cockpit landing page. All four queue surfaces now agree on NO-REC vs `?`.

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

### 2026-04-28T10:42:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1577-f10--extend-no-rec-distinction-to-landin.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-929562df
- **Timestamp:** 2026-06-02T14:58:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `curl -sf "$(bin/fw watchtower url)/" | grep -qE 'NO-REC' && echo "NO-REC pill present" || echo "NO-REC pill missing"`
### 2026-04-28T11:07:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
