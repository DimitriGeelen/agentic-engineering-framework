---
id: T-1416
name: "T-1388 B6: split /approvals into Decisions vs Verifications"
description: >
  T-1388 B6: split /approvals into Decisions vs Verifications

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T08:04:15Z
last_update: '2026-08-16T22:24:31Z'
date_finished: 2026-04-24T08:09:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1416: T-1388 B6: split /approvals into Decisions vs Verifications

## Context

T-1388 build decomposition, unit B6 (F5 fix). The /approvals page shows
97 Human ACs below 4 strategic decisions; the scroll makes decisions feel
buried. Per the research artifact (§B6):
- Group nav: "4 decisions, 97 verifications" instead of "113 items"
- Visual split: Tier 0 + GO/NO-GO are **decisions** (strategic); Human ACs
  are **verifications** (rubber-stamp or review checks)

Scope stays UI-side — no backend data model change.

## Acceptance Criteria

### Agent
- [x] Summary bar groups counts into "Decisions" (Tier 0 + GO) vs "Verifications" (Human ACs) with both totals and breakdown
- [x] Group heading `<h2 id="section-verifications">Verifications</h2>` introduced above Section C (clarifies category intent; retains detailed H3 "Human Acceptance Criteria" with rubber-stamp/review sub-text)
- [x] Summary-bar cells are anchor links to their respective sections (jump past long ACs list)
- [x] Existing Playwright tests for /approvals + inception still pass (16/16)
- [x] New regression class `TestDecisionsVsVerificationsSplit` asserts labels + anchor IDs + anchor-href links (3 tests)

## Verification

# 1. Template parses
python3 -c "from jinja2 import Environment, FileSystemLoader; Environment(loader=FileSystemLoader('web/templates')).get_template('_approvals_content.html')"
# 2. Group labels render
grep -q "Decisions" web/templates/_approvals_content.html
grep -q "Verifications" web/templates/_approvals_content.html
# 3. Anchor IDs present on section headers
grep -qE 'id="section-decisions"' web/templates/_approvals_content.html
grep -qE 'id="section-verifications"' web/templates/_approvals_content.html
# 4. Existing body-assumption regression still passes
python3 -m pytest tests/playwright/test_inception.py::TestBodyAssumptionFallback -q 2>&1 | grep -qE "4 passed"

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

### 2026-04-24T08:04:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1416-t-1388-b6-split-approvals-into-decisions.md
- **Context:** Initial task creation

### 2026-04-24T08:09:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e64083a2
- **Timestamp:** 2026-06-02T14:57:19Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 10
     - evidence: `python3 -m pytest tests/playwright/test_inception.py::TestBodyAssumptionFallback -q 2>&1 | grep -qE "4 passed"`
