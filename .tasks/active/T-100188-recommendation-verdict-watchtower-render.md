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

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-100186, T-100187]
created: 2026-07-05T00:30:00Z
last_update: 2026-07-04T23:05:45Z
date_finished:
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
---

# T-100188: Recommendation Verdict Watchtower render (T-100186 GO slice B)

## Context

Slice B of T-100186 GO (decided 2026-07-05). Renders the claims-verdict produced by T-100187 where the operator decides. Research artifact: `docs/reports/T-100186-reviewer-assisted-inception-decides.md`. Dependency T-100187 SHIPPED (landed on origin/master 2026-07-05).

**WIP state (S-2026-0705, budget-gated mid-build):** implementation complete and committed on local branch `t100188-verdict-render` in worktree `.claude/worktrees/t100188` (commit "T-100188: WIP — …", NOT yet pushed — budget gate blocked push). Done: `web/shared.py:extract_recommendation_claims_verdict` (mirrors extract_reviewer_verdict), `web/blueprints/inception.py` (extract + exclude "Recommendation Verdict" heading from extra_sections + pass claims_verdict), `web/templates/inception_detail.html` (styled claims-verdict-block table under Agent Recommendation, CONFIRMED/CONTRADICTED/UNVERIFIED palette), `web/blueprints/approvals.py` + `web/templates/_approvals_content.html` (Evidence: N/M badge on pending-inception rows). REMAINING: (1) unit test for the extractor (pin table-row parse + absent-block None), (2) Playwright test per T-971 AC, (3) push branch + `bin/fw integrate run master --push` from the worktree, (4) sync task file into MAIN, live-verify on Watchtower, then `fw task review T-100188` for the [REVIEW] Human AC.

## Acceptance Criteria

### Agent
- [ ] `/inception/<id>` renders the Recommendation Verdict table (per-claim status + overall) beside the recommendation when the block exists; page unchanged when absent
- [ ] `/approvals` inception rows show a compact evidence badge (confirmed/total or overall verdict); absent block renders no badge
- [ ] Playwright test covers: verdict table visible on a fixture inception with a verdict block; page 200s cleanly without one (T-971 rule)
- [ ] No change to the decide form/actions — verdict is display-only

### Human
- [ ] [REVIEW] Verdict placement and badge read clean on the decide page
  **Steps:**
  1. Open `{watchtower_url}/inception/<a queued inception with a verdict>` (run `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review <T-XXX>` to get the exact URL)
  2. Check the verdict table sits beside/under the recommendation without crowding it; check /approvals badge
  **Expected:** verdict scannable at a glance; layout reads clean
  **If not:** note the crowded element; agent adjusts template spacing

## Verification

# Render-surface task (P-013): keep the [REVIEW] Human AC above.
# Fill concrete curl/playwright commands while building (P-011).

## RCA

<!-- non-bug build slice — leave empty -->

## Decisions

## Updates

### 2026-07-04T23:05:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
