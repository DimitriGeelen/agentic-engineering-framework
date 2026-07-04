---
id: T-100188
name: "Recommendation Verdict render on /inception/<id> + /approvals badge (T-100186 GO slice B)"
description: >
  T-100186 GO slice B: Watchtower renders the "## Recommendation Verdict" block
  (produced by the T-100187 validator) beside the recommendation on the
  /inception/<id> decide page, and /approvals shows a compact evidence badge
  (e.g. "evidence: 7/7 confirmed") per queued inception. Server-side template
  change only; no new JS dependencies. Depends on T-100187.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: [T-100186, T-100187]
created: 2026-07-05T00:30:00Z
last_update: '2026-07-05T00:30:00Z'
date_finished:
---

# T-100188: Recommendation Verdict Watchtower render (T-100186 GO slice B)

## Context

Slice B of T-100186 GO (decided 2026-07-05). Renders the claims-verdict produced by T-100187 where the operator decides. Research artifact: `docs/reports/T-100186-reviewer-assisted-inception-decides.md`. Blocked until T-100187 ships the verdict block schema.

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
