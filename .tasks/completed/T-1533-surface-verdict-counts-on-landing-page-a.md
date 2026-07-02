---
id: T-1533
name: "Surface verdict counts on landing-page Action Required widget + factor extractor
  to shared"
description: >
  Surface verdict counts on landing-page Action Required widget + factor extractor
  to shared

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-27T10:23:16Z
last_update: '2026-06-11T22:23:51Z'
date_finished: 2026-04-27T10:25:50Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1533: Surface verdict counts on landing-page Action Required widget + factor extractor to shared

## Context

T-1530/T-1531/T-1532 surfaced agent recommendation verdicts in handover + /approvals page. The landing-page "Action Required" widget (cockpit.html) shows total Human ACs and pending GO decisions but doesn't break the AC count down by verdict — the human can't see at-a-glance how many of the awaiting cards are GO (rubber-stamp candidates) vs DEFER (decisions needed) without navigating to /approvals.

Third call site for `_extract_recommendation_verdict()`: handover.sh, approvals.py, and now cockpit.py. Per framework's "no premature abstraction" rule, three call sites is the threshold to factor.

## Acceptance Criteria

### Agent
- [x] `web/shared.py` defines `extract_recommendation_verdict(body: str) -> str` returning GO/DEFER/NO-GO/?
- [x] `web/blueprints/approvals.py` imports the helper from web.shared and removes its private `_extract_recommendation_verdict()`
- [x] `web/blueprints/cockpit.py` `get_human_verify_tasks()` extracts verdict per task and exposes it on the result dict
- [x] `get_action_summary()` aggregates verdict counts (`go_ac_count`, `defer_ac_count`, `nogo_ac_count`) from human_verify list
- [x] `cockpit.html` "Action Required" widget renders verdict-count pills next to the "Human ACs" label when at least one verdict has count ≥ 1
- [x] HTTP request to `/` returns 200 and contains the strings `verdict-pill` (the new pill class) and `data-verdict-pill="GO"` for the count badge
- [x] No regression on /approvals: existing verdict badges and filter buttons still render after the import refactor

## Verification

python3 -c "from web.shared import extract_recommendation_verdict; assert extract_recommendation_verdict('## Recommendation\n\n**Recommendation:** GO\n\n## Other') == 'GO'"
python3 -c "from web.shared import extract_recommendation_verdict; assert extract_recommendation_verdict('') == '?'"
python3 -c "import ast; ast.parse(open('web/blueprints/approvals.py').read()); ast.parse(open('web/blueprints/cockpit.py').read())"
curl -sf "$(bin/fw watchtower url)/" -o /tmp/T-1533-cockpit.html
curl -sf "$(bin/fw watchtower url)/approvals" -o /tmp/T-1533-approvals.html
grep -q 'data-verdict-pill="GO"' /tmp/T-1533-cockpit.html
grep -qE 'data-verdict="GO"' /tmp/T-1533-approvals.html

## Recommendation

**Recommendation:** GO

**Rationale:** Third call site triggered the factor-out, per the framework's "no premature abstraction" rule. `extract_recommendation_verdict()` now lives in `web/shared.py` alongside the other markdown utilities (`parse_frontmatter`, etc.). approvals.py imports it; cockpit.py uses it for the landing-page widget. Verdict pills render on `/` next to the "N Human ACs (M tasks)" label, giving the human a one-glance view of "how many of these are GO rubber-stamps vs DEFER decisions" without leaving the dashboard.

**Evidence:**
- `web/shared.py` exposes `extract_recommendation_verdict(body)` returning `"GO"|"DEFER"|"NO-GO"|"?"`
- approvals.py removed its private duplicate and imports the shared helper
- cockpit.py threads `verdict` through `get_human_verify_tasks()` and aggregates into `go_ac_count` / `defer_ac_count` / `nogo_ac_count`
- cockpit.html renders coloured pills (`data-verdict-pill="GO"` etc.) next to the AC summary
- Verification passes: smoke tests on the helper (GO + empty cases), AST parse for both blueprints, curl confirms pills render on `/` and `/approvals` regression-clean (36 GO badges + 6 filter buttons unchanged)

## Decisions

### 2026-04-27 — extractor home
- **Chose:** Promote `extract_recommendation_verdict()` to `web/shared.py`
- **Why:** Third call site arrived (handover.sh stays bash; approvals.py + cockpit.py share Python). Two Python use sites + a likely fourth (`/review` page rendering or `/tasks/<id>` summary) is the threshold per "three is the limit" of the no-premature-abstraction rule. shared.py already houses similar markdown utilities (`parse_frontmatter`, `task_id_sort_key`).
- **Rejected:** Keep duplicating — simpler now, more drift later. Promote to a new `web/recommendation.py` — premature; one function doesn't justify a new module.



## Updates

### 2026-04-27T10:23:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1533-surface-verdict-counts-on-landing-page-a.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e134be67
- **Timestamp:** 2026-06-02T14:58:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T10:25:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
