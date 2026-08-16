---
id: T-100188
name: "Recommendation Verdict render on /inception/<id> + /approvals badge (T-100186
  GO slice B)"
description: >
  T-100186 GO slice B: Watchtower renders the "## Recommendation Verdict" block
  (produced by the T-100187 validator) beside the recommendation on the
  /inception/<id> decide page, and /approvals shows a compact evidence badge
  (e.g. "evidence: 7/7 confirmed") per queued inception. Server-side template
  change only; no new JS dependencies. Depends on T-100187.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-100186, T-100187]
created: 2026-07-05T00:30:00Z
last_update: '2026-08-16T22:23:58Z'
date_finished: 2026-07-06T12:58:57Z
cost_estimate_proposed:
  - ts: '2026-07-04T22:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 5
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=5 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-04T22:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      audit_severity=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:23:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100188: Recommendation Verdict Watchtower render (T-100186 GO slice B)

## Context

Slice B of T-100186 GO (decided 2026-07-05). Renders the claims-verdict produced by T-100187 where the operator decides. Research artifact: `docs/reports/T-100186-reviewer-assisted-inception-decides.md`. Blocked until T-100187 ships the verdict block schema.

## Acceptance Criteria

### Agent
- [x] `/inception/<id>` renders the Recommendation Verdict table (per-claim status + overall) beside the recommendation when the block exists; page unchanged when absent
- [x] `/approvals` inception rows show a compact evidence badge (confirmed/total or overall verdict); absent block renders no badge
- [x] Playwright test covers: verdict table visible on a fixture inception with a verdict block; page 200s cleanly without one (T-971 rule)
- [x] No change to the decide form/actions — verdict is display-only

### Human
- [ ] [REVIEW] Verdict placement and badge read clean on the decide page
  **Steps:**
  1. Open `{watchtower_url}/inception/<a queued inception with a verdict>` (run `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review <T-XXX>` to get the exact URL)
  2. Check the verdict table sits beside/under the recommendation without crowding it; check /approvals badge
  **Expected:** verdict scannable at a glance; layout reads clean
  **If not:** note the crowded element; agent adjusts template spacing

## Verification

# Render-surface task (P-013): keep the [REVIEW] Human AC above.
# Origin-based checks (MAIN's branch lags origin/master where this lands).
git show origin/master:web/shared.py > /tmp/.t100188-shared.py && grep -q "def extract_recommendation_claims_verdict" /tmp/.t100188-shared.py
git show origin/master:web/templates/inception_detail.html > /tmp/.t100188-tpl.html && grep -q "data-claims-overall" /tmp/.t100188-tpl.html
git show origin/master:web/templates/_approvals_content.html > /tmp/.t100188-appr.html && grep -q "claims-badge" /tmp/.t100188-appr.html
git show origin/master:tests/playwright/test_inception_claims_verdict.py > /tmp/.t100188-pw.py && grep -q "claims-verdict-block" /tmp/.t100188-pw.py
rm -rf /tmp/.t100188-tree && mkdir -p /tmp/.t100188-tree && git archive origin/master web tests lib | tar -x -C /tmp/.t100188-tree && cd /tmp/.t100188-tree && PYTHONPATH=. python3 -m pytest tests/unit/test_extract_recommendation_claims_verdict.py -q > /dev/null 2>&1

## RCA

<!-- non-bug build slice — leave empty -->

## Decisions

- **Parse the on-disk verdict block in `web/shared.py` rather than importing `lib.reviewer.recommendation_claims`** — the markdown block IS the contract (same pattern as `extract_reviewer_verdict`); keeps web decoupled from the reviewer's dataclasses and works on completed/ tasks the reviewer never re-scans.
- **Badge shows `passed/total` + overall, not overall alone** — "Evidence: 7/9" tells the operator where to look before opening the page; a bare CONTRADICTED chip would force a click to learn severity.

## Recommendation

**Recommendation:** GO — approve the render.

**Rationale:** Both surfaces are display-only additions mirroring the existing Reviewer Verdict block's pattern and palette; the decide form is untouched. All four Agent ACs are ticked with tests pinning the contract both ways (block present → table renders; block absent → clean 200, no artifact).

**Evidence:**
- `web/shared.py:extract_recommendation_claims_verdict` + 7 unit tests (`tests/unit/test_extract_recommendation_claims_verdict.py`, all pass)
- `/inception/<id>` claims-verdict table + `/approvals` Evidence badge — 2 Playwright tests (`tests/playwright/test_inception_claims_verdict.py`, both pass)
- Sibling extractor regression suite green (49 passed)

## Updates

### 2026-07-04T23:05:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5d687f2c
- **Timestamp:** 2026-07-06T12:58:59Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 7
     - evidence: `rm -rf /tmp/.t100188-tree && mkdir -p /tmp/.t100188-tree && git archive origin/master web tests lib | tar -x -C /tmp/.t100188-tree && cd /tmp/.t100188-tree && PYTHONPATH=. python3 -m pytest tests/unit`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`

### 2026-07-06T12:58:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
