---
id: T-1532
name: "Verdict counts header on Watchtower Awaiting-Human-ACs section"
description: >
  Verdict counts header on Watchtower Awaiting-Human-ACs section

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-27T10:19:54Z
last_update: '2026-06-11T22:23:51Z'
date_finished: 2026-04-27T10:21:42Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1532: Verdict counts header on Watchtower Awaiting-Human-ACs section

## Context

T-1531 added per-card verdict badges. Next leverage: surface verdict counts in the filter-button row at the top of the Awaiting Human ACs section, and let the human click-to-filter by verdict. Companion to existing Review/Rubber-stamp/Stale filter buttons. Goal: human sees "GO (18)" + "DEFER (4)" at a glance, can isolate the GO batch in one click.

## Acceptance Criteria

### Agent
- [x] `_approvals_content.html` renders two new verdict filter buttons — `GO (N)` and `DEFER (N)` — alongside the existing Review/Rubber-stamp/Stale filter row
- [x] `filterACs()` JS function handles the `go` and `defer` filter values, hiding cards whose `data-verdict` doesn't match
- [x] When N=0 for a verdict, the corresponding button is suppressed (don't show `GO (0)`)
- [x] HTTP request to `/approvals` returns 200 and the response contains the strings `data-filter="go"` and `data-filter="defer"` when both verdicts have ≥1 task
- [x] Existing filter buttons (All / Review / Rubber-stamp / Stale) continue to render

## Verification

python3 -c "import ast; ast.parse(open('web/blueprints/approvals.py').read())"
curl -sf "$(bin/fw watchtower url)/approvals" -o /tmp/T-1532-approvals.html
grep -q 'data-filter="go"' /tmp/T-1532-approvals.html
grep -q 'data-filter="defer"' /tmp/T-1532-approvals.html
grep -q 'data-filter="all"' /tmp/T-1532-approvals.html
grep -q "filter === 'go'" /tmp/T-1532-approvals.html

## Recommendation

**Recommendation:** GO

**Rationale:** Reuses the existing filter-button row (no new UI surface), threads the verdict counts through Jinja `selectattr` filters (no Python changes — verdict was already exposed by T-1531), and gives the human a one-click way to isolate the GO batch (rubber-stamp candidates) or the DEFER batch (decisions needed). NO-GO button only renders when a NO-GO task exists, keeping the row compact.

**Evidence:**
- `_approvals_content.html` filter row now shows `GO (18)` + `DEFER (10)` buttons; verdicts thread directly off `pending_acs[i].verdict` (set by T-1531's `_extract_recommendation_verdict()`)
- `data-filter="go"` and `data-filter="defer"` attributes render in the page
- `filterACs()` JS handles the new filter values (`filter === 'go' && verdict === 'GO'` etc.)
- All existing filters (Review/Rubber-stamp/Stale/All) continue to render
- NO-GO button is correctly suppressed (count=0)



## Updates

### 2026-04-27T10:19:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1532-verdict-counts-header-on-watchtower-awai.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b4daac21
- **Timestamp:** 2026-06-02T14:58:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T10:21:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
